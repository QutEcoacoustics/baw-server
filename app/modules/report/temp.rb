# frozen_string_literal: true
# Define the parameters
date_start = '2022-01-01'
date_end = '2022-01-10'
bucket_interval = '1 day'
bucket_count = 10

# Build the CTE using string interpolation for the parameters
cte_sql = "WITH my_parameters AS (
  SELECT
    tsrange('#{date_start}', '#{date_end}') AS my_range,
    interval '#{bucket_interval}' AS bucket_interval,
    #{bucket_count} AS bucket_count
)"

# Use Arel for the main query
my_parameters = Arel::Table.new('my_parameters')
series = Arel::Table.new('series')

query = Arel::SelectManager.new
query.project([
  Arel.sql('series'),
  Arel.sql("tsrange(
    lower(my_range) + ((series - 1) * bucket_interval),
    lower(my_range) + (series * bucket_interval)
  )").as('time_bucket')
])

query.from(my_parameters)
query.join(Arel.sql('CROSS JOIN generate_series(1, my_parameters.bucket_count) AS series'))

# Combine the CTE and the main query
final_sql = cte_sql + "\n" + query.to_sql

# To execute:
# ActiveRecord::Base.connection.execute(final_sql)

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

    def bucket_settings_table(time_boundaries)
      min = Arel.sql('?::timestamp', Arel.quoted(time_series_config[:start_time]))
      max = Arel.sql('?::timestamp', Arel.quoted(time_series_config[:end_time]))

      interval = time_series_config[:interval]
      bucket_interval_quoted = Arel.sql('INTERVAL ?', Arel.quoted(interval))
      bucket_counting_expression = case interval
                                   when '1 month' then TimeSeries.count_number_of_buckets_monthly
                                   when '1 year' then TimeSeries.count_number_of_buckets_yearly
                                   else TimeSeries.count_number_of_buckets_default
                                   end

      calculated_settings = Arel::Table.new('calculated_settings')
      calculated_settings_query = Arel::SelectManager.new
        .project(
          time_boundaries
          bucket_interval_quoted.as('bucket_interval'),
          bucket_counting_expression.as('bucket_count'),
          min.as('min_value'),
          max.as('max_value')
        )
      calculated_settings_cte = Arel::Nodes::As.new(calculated_settings, calculated_settings_query)
      ReportQuery.new(calculated_settings, calculated_settings_cte)
    end

    # def bucket_counting_method(interval)
    #   case interval
    #   when '1 month' then TimeSeries.expr_bucket_count_month
    #   when '1 year' then TimeSeries.expr_bucket_count_year
    #   else TimeSeries.expr_bucket_count_default
    #   end
    # end

    def count_number_of_buckets_default(min, max, interval)
    Arel.grouping(max.extract('epoch') - min.extract('epoch') / interval.extract('epoch'))
    end
    end

    def count_number_of_buckets_monthly(min, max, interval)
      # subtracting a timestamp truncated to month from itself gives the
      # remainder of days + hours:minutes:seconds. if the end time remainder is
      # greater than the start time, there is a partial month, so add 1
      Arel.grouping(
        (max.extract('year') - min.extract('year')) * 12 +
        (max.extract('month') - min.extract('month')) +
        Arel.sql(
          <<~SQL.squish
            CASE WHEN
              (EXTRACT(EPOCH FROM max) - EXTRACT(EPOCH FROM DATE_TRUNC('month', max))) >
              (EXTRACT(EPOCH FROM min) - EXTRACT(EPOCH FROM DATE_TRUNC('month', min)))
            THEN 1 ELSE 0 END
          SQL
        )
      )

    end
    end

    def count_number_of_buckets_yearly(min, max, interval)
    end

    def bucketed_time_series_table(bucket_settings)
      bucket_settings.table.project(
            bucket_settings.table[:bucket_count].ceil
          )
      bucketed_time_series = Arel::Table.new('bucketed_time_series')
      all_buckets_query = Arel::SelectManager.new
        .project(
          TimeSeries.generate_series(bucket_settings.table.project(
            bucket_settings.table[:bucket_count].ceil
          )).as('bucket_number'),
          TimeSeries.bucket_start_time.as('bucket_start_time'),
          TimeSeries.bucket_end_time.as('bucket_end_time')
        )
      # .project(
      #   TimeSeries.generate_series(1, TimeSeries.select_ceiling_bucket_count).as('bucket_number'),
      #   TimeSeries.bucket_start_time.as('bucket_start_time'),
      #   TimeSeries.bucket_end_time.as('bucket_end_time')
      # )
      all_buckets_cte = Arel::Nodes::As.new(all_buckets, all_buckets_query)
    end

    # Generate a series of integers from 1 to the specified end
    # @param stop_expr [String] Stop expression for the series
    # @return [Arel::Nodes::NamedFunction]
    def generate_series(expr)
      Arel::Nodes::NamedFunction.new('generate_series', [1, expr])
    end

    # Generate a series of integers
    # @param start_expr [String] Start expression for the series
    # @param stop_expr [String] Stop expression for the series
    # @return [Arel::Nodes::SqlLiteral] SQL literal node
    def generate_series_old(start_expr, stop_expr)
      Arel.sql("generate_series(#{start_expr}, #{stop_expr}::integer)")
    end

    def select_ceiling_bucket_count
      Arel.sql(
        <<~SQL.squish
          (SELECT CEILING(bucket_count) FROM calculated_settings)
        SQL
      )
    end

    def string_as_timestamp_node(date)
      Arel.sql('?::timestamp', Arel.quoted(date))
    end

    # @param start_date [String] Start date in ISO format
    # @param end_date [String] End date in ISO format
    # @param bucket_interval [String] PostgreSQL interval string e.g. '1 hour'
    # @return [Query] A query object with the time boundaries
    def time_boundaries(time_series_config)
      start_date = time_series_config[:start_time]
      end_date = time_series_config[:end_time]

      start_quoted = Arel.sql('?::timestamp', Arel.quoted(start_date))
      end_quoted = Arel.sql('?::timestamp', Arel.quoted(end_date))

      time_range = time_range_expression(start_quoted, end_quoted)

      bucket_interval = time_series_config[:interval]
      bucket_interval_quoted = Arel.sql('INTERVAL ?', Arel.quoted(bucket_interval))

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


    # closed open time range from [start_date, end_date)
    def time_range_expression(start_quoted, end_quoted)
      range_function = Arel::Nodes::NamedFunction.new(
        'tsrange', [
          start_quoted,
          end_quoted,
          Arel::Nodes::SqlLiteral.new("'[)'")
        ]
      )
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

    def bucket_start_time_2(bucket_settings)
      first = bucket_settings.table.project(:min_value)

      sub_one = bucket_settings.table.project(bucket_settings.table[:bucket_count].ceil.cast('int'))
      sub_two = generate_series(sub_one) - 1
      interval = bucket_settings.table.project(:bucket_interval)
      group_two = Arel.grouping(Arel::Nodes::Multiplication.new(sub_two, interval))

      expr = Arel.grouping(first + group_two)
    end

    def bucket_start_time
      Arel.sql(
        <<~SQL.squish
          (SELECT min_value FROM calculated_settings) +
                          ((#{generate_series(select_ceiling_bucket_count)} - 1) *
                          (SELECT bucket_interval FROM time_boundaries))
        SQL
      )
    end

    def bucket_end_time
      Arel.sql(
        <<~SQL.squish
          (SELECT min_value FROM calculated_settings) +
          (#{generate_series(select_ceiling_bucket_count)} *
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
