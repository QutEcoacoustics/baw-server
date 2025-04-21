# frozen_string_literal: true

module Report
  # Provides functionality for generating time series reports with properly bucketed time intervals
  module TimeSeries
    module_function

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
  end
end
