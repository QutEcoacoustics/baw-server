# frozen_string_literal: true

module Report
  module Ctes
    module Accumulation
      # Defines a CTE that provides configuration values for time series analysis
      #
      # Projects input options specifying a reporting period (start and end
      # time) and an interval to use for temporal aggregation (bucketing)
      class TimeRangeAndInterval < Cte::NodeTemplate
        table_name :time_range_and_interval

        options do
          {
            start_time: Time.utc(2000, 1, 1),
            end_time: Time.utc(2000, 1, 7),
            interval: '1 day'
          }
        end

        select do
          lower, upper, interval = options.values_at(:start_time, :end_time, :interval)
          arel_tsrange_expr = Report::TimeSeries.arel_tsrange(lower, upper).as('time_range')
          bucket_interval_expr = Report::TimeSeries.arel_interval(interval).as('bucket_interval')
          Arel::SelectManager.new.project(arel_tsrange_expr, bucket_interval_expr)
        end
      end
    end
  end
end
