# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Return a cte with fields for start, end, and previous end time
      # Rows are # sorted based on the lower_field (start time)
      # previous end time is a derived column (null for the first row)
      # representing the end_time of the previous row. getting this here so it
      # can be used to classify events into groups in the next step
      class SortTemporalEvents < Report::Cte::NodeTemplate

        table_name :sort_temporal_events

        depdendencies source: BaseEventReport

        # lower and upper field are the attribute names of timestamp columns on
        # the `source` table dependency that will be used to calculate coverage
        default_options do
          {
            analysis_result: false,
            lower_field: nil,
            upper_field: nil
          }
        end

        select do
          analysis_result = options.fetch(:analysis_result)
          time_lower = source[options[:lower_field]]
          time_upper = source[options[:upper_field]]

          window = build_window(
            partition_by: analysis_result ? source[:result] : nil,
            sort_by: time_lower
          )

          lag = build_lag(time_upper, window)
          fields = fields(time_lower, time_upper, lag, result: analysis_result ? source[:result] : nil)

          source.project(fields)
        end

        def self.build_window(sort_by:, partition_by: nil)
          window = Arel::Nodes::Window.new
          window = window.partition(partition_by) if partition_by
          window.order(sort_by)
        end

        def self.build_lag(column, window)
          Arel::Nodes::NamedFunction.new('LAG', [column]).over(window)
        end

        def self.fields(time_lower, time_upper, lag, result: nil)
          fields = [time_lower.as('start_time'), time_upper.as('end_time'), lag.as('prev_end')]
          fields.append(result.as('result')) if result
          fields
        end
      end
    end
  end
end
