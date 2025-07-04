# frozen_string_literal: true

module Report
  module Section
    class BucketedTimeSeries < Report::Section
      step TABLE_TIME_RANGE_AND_INTERVAL do |options|
        time_range_and_interval_query(options)
      end

      step TABLE_NUMBER_OF_BUCKETS, depends_on: TABLE_TIME_RANGE_AND_INTERVAL do |time_range_and_interval, options|
        number_of_buckets_query(time_range_and_interval, options[:interval])
      end

      step TABLE_BUCKETED_TIME_SERIES, depends_on: TABLE_NUMBER_OF_BUCKETS do |number_of_buckets|
        bucketed_time_series_query(number_of_buckets)
      end
    end
  end
end
