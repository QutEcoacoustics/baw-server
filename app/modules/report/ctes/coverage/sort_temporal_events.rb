# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # This CTE uses two input fields that represent the lower/upper time boundaries
      # of the entity (e.g. audio_recording) for which coverage will be calculated.
      # Rows are ordered by the lower_field. If the analysis_result options is true, the data is partitioned by
      # the 'result' field (AnalysisJobsItem result) when ordered.
      # The CTE projection returns the lower/upper fields, a previous end time column (null for first row),
      # and the 'result' status if applicable.
      # The previous end time row will be used to classify 'events' into groups.
      class SortTemporalEvents < Cte::NodeTemplate
        table_name :sort_temporal_events

        dependencies base_table: BaseEventReport

        # lower and upper field are the attribute names of timestamp columns on
        # the `base_table` table dependency that will be used to calculate coverage intervals
        #
        # for the audio events report these fields are: recorded_date, end_date
        options do
          {
            analysis_result: false,
            lower_field: nil,
            upper_field: nil
          }
        end

        # given a lower and upper, and an optional partition by clause
        # project audio recording start_time, end_time, prev_end time, and the 'result' status (if applicable)
        select do
          analysis_result = options.fetch(:analysis_result)
          time_lower = base_table[options[:lower_field]]
          time_upper = base_table[options[:upper_field]]

          window = build_window(
            partition_by: analysis_result ? base_table[:result] : nil,
            sort_by: time_lower
          )

          lag = build_lag(time_upper, window)
          fields = fields(time_lower, time_upper, lag, result: analysis_result ? base_table[:result] : nil)
          base_table.project(*fields)
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
