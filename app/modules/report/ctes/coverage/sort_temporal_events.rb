# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Prepares temporal data for interval analysis
      #
      # This CTE takes a base table of temporal events, with the expected format
      # of lower_field, upper_field (i.e. start time, end time).
      #
      # It returns rows ordered by the lower field, and a column `prev_end` with
      # the end time of the previous event. This is used by {CategoriseIntervals}
      # to classify events into groups based on the gaps between them.
      #
      # If the `analysis_result` option is true, the events are partitioned by
      # the `result` column before sorting, so that each result type is treated
      # as a separate sequence.
      #
      # == query output
      #
      #  emits columns:
      #    start_time (timestamp)
      #    end_time   (timestamp)
      #    prev_end   (timestamp)             -- the end time of the previous event (in the group), or NULL if it is the first
      #    result (analysis_jobs_item_result) -- (optional) if analysis_result is true, the analysis result field
      #
      #  emits rows: one per event from the base table
      class SortTemporalEvents < Cte::NodeTemplate
        table_name :sort_temporal_events

        dependencies base_table: BaseEventReport

        # Default options for an audio report, using start/end times of audio recordings
        #
        # @return [Hash{Symbol => Object}] options
        # @options options [Symbol] :lower_field (:recorded_date) the attribute name of the lower time bound column
        # @options options [Symbol] :upper_field (:recorded_end_date) the attribute name of the upper time bound column
        # @options options [Boolean] :analysis_result (false) whether to partition by a `result` column
        options do
          {
            lower_field: :recorded_date,
            upper_field: :recorded_end_date,
            analysis_result: false
          }
        end

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
