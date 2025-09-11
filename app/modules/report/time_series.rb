# frozen_string_literal: true

module Report
  # Provides functionality for analysing and reporting time series data.
  # TODO: - infer start/end if no start/end provided
  # e.g. if no start date, use the earliest date in the data set
  # if no end date, use the latest date in the data set
  # if no start date and no end date, use the earliest and latest dates in the data set
  # if no data, use a default range e.g. 1 year from now
  # if report start provided by user, this should be the epoch we use - no
  # rounding. without start date, have to calculate the epoch

  module TimeSeries
    module_function

    # A hash mapping of valid bucket size strings (keys) for reporting
    #   and their corresponding PostgreSQL interval strings (values).
    BUCKET_ENUM = {
      'day' => '1 day',
      'week' => '1 week',
      'fortnight' => '2 week',
      'month' => '1 month',
      'year' => '1 year'
    }.freeze

    # Get the interval string for a bucket from BUCKET_ENUM
    # @param bucket [String] the bucket size
    # @return [String] the bucket interval string
    def bucket_interval(bucket_size)
      BUCKET_ENUM[bucket_size] || '1 day'
    end

    # Return a validated hash of time series reporting values from params
    # @param [Hash] parameters to parse
    # @param [Proc] time_range_parser a proc that returns an array of the
    #   report start and end datetime strings from the input parameters.
    # @param [Proc] bucket_size_parser a proc that returns a valid bucket size
    #   string from the input parameters
    # @return [Hash] with keys :start_time, :end_time, :bucket_size, :interval
    def ts_options(parameters,
                   base_table: nil,
                   time_range_parser: TimeSeries.parse_time_range_from_request_params,
                   bucket_size_parser: TimeSeries.parse_bucket_size_from_request_params)
      scaling_factor = parameters.dig(:options, :scaling_factor) || 1920
      time_range = time_range_parser.call(parameters)
      start_time, end_time = validate_start_end_time(time_range)

      parsed_bucket = bucket_size_parser.call(parameters)
      bucket_size = validate_bucket_size(parsed_bucket)

      {
        base_table: base_table,
        start_time: start_time,
        end_time: end_time,
        bucket_size: bucket_size,
        interval: TimeSeries.bucket_interval(bucket_size),
        scaling_factor: scaling_factor
      }
    end

    # Reports allow future dates; requests will emit empty results but can be
    # reused to show data as it becomes available.
    def validate_start_end_time(time_range)
      start_time, end_time = time_range.map { |time| TimeSeries.string_to_iso8601(time) }

      raise ArgumentError, "invalid time range, #{start_time} is > #{end_time}" unless start_time < end_time

      Rails.logger.warn('future start time') if start_time > Time.zone.now
      Rails.logger.warn('future end time') if end_time > Time.zone.now

      [start_time, end_time]
    end

    def validate_bucket_size(bucket)
      return bucket if BUCKET_ENUM.keys.include?(bucket)

      message = if bucket.nil?
                  'No bucket size specified.'
                else
                  "Invalid bucket size: #{bucket}."
                end

      Rails.logger.warn("#{message} Defaulting to 'day'.")
      'day'
    end

    def string_to_iso8601(datetime_string)
      begin
        datetime = DateTime.iso8601(datetime_string)
      rescue ArgumentError
        raise ArgumentError, "time string (#{datetime_string}) must be valid ISO 8601"
      end
      datetime
    end

    def parse_time_range_from_request_params
      lambda { |parameters|
        start_time = parameters.dig(:options, :start_time)
        end_time = parameters.dig(:options, :end_time)
        [start_time, end_time]
      }
    end

    def parse_bucket_size_from_request_params
      lambda { |parameters|
        bucket = parameters.dig(:options, :bucket_size)
        bucket
      }
    end

    # Returns an interval expression for the given interval string
    def arel_interval(interval)
      Arel.sql('INTERVAL ?', Arel.quoted(interval))
    end

    # Returns a query that projects a lower and upper datetime to a tsrange
    def arel_project_ts_range(start_date, end_date)
      range = TimeSeries.arel_tsrange(start_date, end_date)
      Arel::Nodes::TableAlias.new(
        Arel::SelectManager.new.project(range.as('range')), 'report_range'
      )
    end

    # Return a tsrange expression for the given start and end dates
    def arel_tsrange(start_date, end_date)
      start_date = arel_cast_datetime(start_date)
      end_date = arel_cast_datetime(end_date)
      Arel::Nodes::NamedFunction.new('tsrange', [start_date, end_date, Arel.quoted('[)')])
    end

    # Casts a given expression to a datetime type
    # ! check which one is appropriate
    def arel_cast_datetime(expr)
      Arel.quoted(expr).cast(:datetime) # => CAST('2000-01-01T12:12:12' AS timestamp without time zone
      # if using .cast(:time) instead:    => CAST('2000-01-01T12:12:12' AS time)
    end

    # Returns an upper function call for the given expression
    def upper(expr)
      Arel::Nodes::NamedFunction.new('upper', [expr])
    end

    # Truncate a date to the specified interval
    def date_trunc(interval, expr)
      Arel::Nodes::NamedFunction.new('date_trunc', [Arel.quoted(interval), expr])
    end

    # Generates a series of numbers starting from 1 to the given expression
    # @return [Arel::Nodes::NamedFunction]
    def generate_series(expr)
      Arel::Nodes::NamedFunction.new('generate_series', [1, expr])
    end
  end
end
