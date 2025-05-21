# frozen_string_literal: true

module Report
  # Namespace for classes and modules used in time series reporting.
  module TimeSeries
    module_function

    extend Report::ArelHelpers
    include Report::ArelHelpers

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
    class StartEndTime
      # @param [Hash] parameters to parse
      # @param [Proc] time_range_parser a proc that returns an array of the
      #   report start and end datetime strings from the input parameters.
      # @param [Proc] bucket_size_parser a proc that returns a valid bucket size
      #   string from the input parameters
      # @return [Hash] with keys :start_time, :end_time, :bucket_size, :interval
      def self.call(parameters,
                    time_range_parser: TimeSeries.parse_time_range,
                    bucket_size_parser: TimeSeries.parse_bucket_size)
        time_range = time_range_parser.call(parameters)
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

      # Reports allow future dates; requests will emit empty results but can be
      # reused to show data as it becomes available.
      def self.validate_start_end_time(time_range)
        start_time, end_time = time_range.map { |time| TimeSeries.string_to_iso8601(time) }

        raise ArgumentError, "invalid time range, #{start_time} is > #{end_time}" unless start_time < end_time

        Rails.logger.warn('future start time') if start_time > Time.zone.now
        Rails.logger.warn('future end time') if end_time > Time.zone.now

        [start_time, end_time]
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

    def string_to_iso8601(datetime_string)
      begin
        datetime = DateTime.iso8601(datetime_string)
      rescue ArgumentError
        raise ArgumentError, 'time string must be valid ISO 8601 dates.'
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
  end
end
