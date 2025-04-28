# frozen_string_literal: true

module Report
  # Provides functionality for generating time series reports with properly bucketed time intervals
  module TimeSeries
    module_function

    include Report::ArelHelpers

    BUCKET_ENUM = {
      'day' => '1 day',
      'week' => '1 week',
      'fortnight' => '2 week',
      'month' => '1 month',
      'year' => '1 year'
    }.freeze

    # Get the interval string for the given bucket from BUCKET_ENUM
    # @param bucket [String] the bucket size
    # @return [String] the bucket interval string
    def bucket_interval(bucket_size)
      BUCKET_ENUM[bucket_size] || '1 day'
    end

    def parse_time_range
      lambda { |parameters|
        start_time = parameters.dig(:options, :start_time)
        end_time = parameters.dig(:options, :end_time)
        [start_time, end_time]
      }
    end

    def parse_bucket_size
      lambda { |parameters|
        bucket = parameters.dig(:options, :bucket_size)
        bucket
      }
    end

    def string_to_iso8601(datetime_string)
      begin
        datetime = DateTime.iso8601(datetime_string)
      rescue ArgumentError
        raise ArgumentError, 'time string must be valid ISO 8601 dates.'
      end
      datetime
    end

    class StartEndTime
      def self.call(parameters,
                    time_range_parser: TimeSeries.parse_time_range,
                    bucket_size_parser: TimeSeries.parse_bucket_size)
        time_range = time_range_parser.call(parameters)
        time_range = time_range.map { |time| TimeSeries.string_to_iso8601(time) }
        start_time, end_time = validate_start_end_time(time_range)

        parsed_bucket = bucket_size_parser.call(parameters)
        bucket_size = validate_bucket_size(parsed_bucket)

        {
          start_time: start_time,
          end_time: end_time,
          bucket_size: bucket_size,
          interval: TimeSeries.bucket_interval(bucket_size)
        }
      end

      # don't truncate end times into the future
      # don't error on future start date - emit warning in the UI
      def self.validate_start_end_time(time_range)
        start_time, end_time = time_range
        raise ArgumentError, 'start_time must be before the current date.' unless start_time < Time.zone.now
        raise ArgumentError, 'end_time must be before the current date.' unless start_time < Time.zone.now
        raise ArgumentError, 'start_time must be before end_time.' unless start_time < end_time

        return [start_time, end_time] unless end_time > Time.zone.now

        Rails.logger.warn('end_time is in the future, defaulting to current time.')
        [start_time, Time.zone.now]
      end

      def self.validate_bucket_size(bucket)
        return bucket if BUCKET_ENUM.keys.include?(bucket)

        message = if bucket.nil?
                    'No bucket size specified.'
                  else
                    "Invalid bucket size: #{bucket}."
                  end

        Rails.logger.warn("#{message} Defaulting to 'day'.")
        'day'
      end
    end

    def string_as_timestamp_node(date)
      Arel.sql('?::timestamp', Arel::Nodes.build_quoted(date))
    end

    # @param start_date [String] Start date in ISO format
    # @param end_date [String] End date in ISO format
    # @param bucket_interval [String] PostgreSQL interval string e.g. '1 hour'
    # @return [Query] A query object with the time boundaries
    def time_boundaries(start_date, end_date, bucket_interval)
      start_quoted = Arel.sql('?::timestamp', Arel::Nodes.build_quoted(start_date))
      end_quoted = Arel.sql('?::timestamp', Arel::Nodes.build_quoted(end_date))
      bucket_interval_quoted = Arel.sql('INTERVAL ?', Arel::Nodes.build_quoted(bucket_interval))

      select = Arel::SelectManager.new
        .project(
          start_quoted.as('report_start_time'),
          end_quoted.as('report_end_time'),
          bucket_interval_quoted.as('bucket_interval')
        )

      table = Arel::Table.new(:time_boundaries)
      cte = Arel::Nodes::As.new(table, select)
      ReportQuery.new(table, cte)
    end

    def cte_time_boundaries(start_date, end_date, bucket_interval)
      Arel.sql(
      <<~SQL.squish
        time_boundaries AS (
            SELECT
                '#{start_date}'::timestamp AS report_start_time,
                '#{end_date}'::timestamp AS report_end_time,
                interval '#{bucket_interval}' AS bucket_interval
        )
      SQL
    )
    end

    def cte_calculated_settings(bucket_count_case)
      Arel.sql(
      <<~SQL.squish
        calculated_settings AS (
          SELECT #{bucket_count_case} AS bucket_count,
          (SELECT report_start_time FROM time_boundaries) AS min_value,
          (SELECT report_end_time FROM time_boundaries) AS max_value
        )
      SQL
    )
    end

    def cte_all_buckets
      Arel.sql(
      <<~SQL.squish
         all_buckets AS (
            SELECT
                #{generate_series(1, select_ceiling_bucket_count)} AS bucket_number,

                (SELECT min_value FROM calculated_settings) +
                ((#{generate_series(1, select_ceiling_bucket_count)} - 1) *
                (SELECT bucket_interval FROM time_boundaries)) AS bucket_start_time,

                (SELECT min_value FROM calculated_settings) +
                (#{generate_series(1, select_ceiling_bucket_count)} *
                (SELECT bucket_interval FROM time_boundaries)) AS bucket_end_time
        )
      SQL
    )
    end

    def bucket_start_time
      Arel.sql(
        <<~SQL.squish
          (SELECT min_value FROM calculated_settings) +
                          ((#{generate_series(1, select_ceiling_bucket_count)} - 1) *
                          (SELECT bucket_interval FROM time_boundaries))
        SQL
      )
    end

    def bucket_end_time
      Arel.sql(
        <<~SQL.squish
          (SELECT min_value FROM calculated_settings) +
          (#{generate_series(1, select_ceiling_bucket_count)} *
          (SELECT bucket_interval FROM time_boundaries))
        SQL
      )
    end

    def bucket_count_default(start_column, end_column, interval_column)
      # extract(epoch from ?)
      (end_column.extract('epoch') - start_column.extract('epoch')) / interval_column.extract('epoch')
    end

    def expr_bucket_count_default
      Arel.sql(
        <<~SQL.squish
          (SELECT
            (EXTRACT(EPOCH FROM report_end_time) - EXTRACT(EPOCH FROM report_start_time)) /
            EXTRACT(EPOCH FROM bucket_interval)
            FROM time_boundaries)
        SQL
      )
    end

    def expr_bucket_count_month
      # subtracting a timestamp truncated to month from itself gives the
      # remainder of days + hours:minutes:seconds. if the end time remainder is
      # greater than the start time, there is a partial month, so add 1
      # Alternative: AGE() function accepts two TIMESTAMP values. It subtracts
      # the second argument from the first one and returns an interval as a
      # result.
      # SELECT date_part ('year', report_age) * 12 +
      #   date_part ('month', report_age)
      #   FROM age (report_start_time, report_end, time) AS report_age
      #  select.new
      #   .project(report_age.date_part('year') * 12 +
      #      report_age.date_part('month'))
      #   .from(table.age).as('report_age')
      Arel.sql(
      <<~SQL.squish
        (SELECT
          ((DATE_PART('year', report_end_time) - DATE_PART('year', report_start_time)) * 12 +
           (DATE_PART('month', report_end_time) - DATE_PART('month', report_start_time))) +
          (CASE WHEN
            (report_end_time - DATE_TRUNC('month', report_end_time)) >
            (report_start_time - DATE_TRUNC('month', report_start_time))
          THEN 1 ELSE 0 END) FROM time_boundaries)
      SQL
    )
    end

    def expr_bucket_count_year
      Arel.sql(
      <<~SQL.squish
        (SELECT
          ((DATE_PART('year', report_end_time) - DATE_PART('year', report_start_time)))
           +
          (CASE WHEN
            (report_end_time - DATE_TRUNC('year', report_end_time)) >
            (report_start_time - DATE_TRUNC('year', report_start_time))
          THEN 1 ELSE 0 END) FROM time_boundaries)
      SQL
    )
    end

    def select_ceiling_bucket_count
      Arel.sql(
        <<~SQL.squish
          (SELECT CEILING(bucket_count) FROM calculated_settings)
        SQL
      )
    end

    # Generate a series of integers
    # @param start_expr [String] Start expression for the series
    # @param stop_expr [String] Stop expression for the series
    # @return [Arel::Nodes::SqlLiteral] SQL literal node
    def generate_series(start_expr, stop_expr)
      Arel.sql("generate_series(#{start_expr}, #{stop_expr}::integer)")
    end

    # Generate bucket time series sql
    # @param start_date [String] Start date in ISO format
    # @param end_date [String] End date in ISO format
    # @param bucket_interval [String] PostgreSQL interval string e.g. '1 hour'
    # @return [String] SQL for generating bucket boundaries
    def time_series(start_date, end_date, bucket_interval)
      bucket_count_case = case bucket_interval
                          when '1 month' then expr_bucket_count_month
                          when '1 year' then expr_bucket_count_year
                          else expr_bucket_count_default
                          end

      time_boundaries = cte_time_boundaries(start_date, end_date, bucket_interval)
      calculated_settings = cte_calculated_settings(bucket_count_case)
      all_buckets = cte_all_buckets
      Arel.sql(
       <<~SQL.squish
         #{time_boundaries},
         #{calculated_settings},
         #{all_buckets}
       SQL
     )
    end

    def width_bucket
      Arel.sql(
        <<~SQL.squish
          WIDTH_BUCKET(
            EXTRACT(EPOCH FROM start_time_absolute),
            EXTRACT(EPOCH FROM (SELECT min_value FROM calculated_settings)),
            EXTRACT(EPOCH FROM (SELECT max_value FROM calculated_settings)),
            (SELECT CEILING(bucket_count)::integer FROM calculated_settings)
          )
        SQL
      )
    end

    def datetime_range_to_array(start_field, end_field)
      Arel::Nodes::SqlLiteral.new("
          array_to_json(ARRAY[
            to_char(#{start_date}, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
            to_char(#{end_date}, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')
          ])
        ").as('range')
    end
  end
end

# problem with epoch for buckets
# probably need a parameter for the report - what time zone do you want the
# report in
# e.g. state boundaries - need to know one or the other

# if report start provided by user, this should be the epoch we use - no rounding
# without start date, have to calculate the epoch e.g.
