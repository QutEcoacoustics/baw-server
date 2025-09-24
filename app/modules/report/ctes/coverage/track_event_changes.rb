# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Defines a CTE that tracks the number of overlapping temporal events at
      # each point in time within a continuous interval.
      #
      # It uses the `stacked_temporal_events` CTE, which provides a timeline of
      # start and end points for all events. This CTE calculates a `running_sum`
      # of the `delta` values (+1 for start, -1 for end) over time for each
      # `group_id`.
      #
      # A `running_sum` greater than 0 indicates that at least one event is
      # active. The `next_event_time` column is also added to mark the timestamp
      # of the next change. This is used by {EventCoverage} to calculate the
      # durations of actual event coverage, within a coverage period.
      #
      # If the `analysis_result` option is true, these calculations are
      # partitioned by the `result` column.
      #
      # == query output
      #
      #  inherits columns from `stacked_temporal_events`:
      #    group_id   (bigint)                      -- sequential group index, 0-based
      #    event_time (timestamp without time zone) -- the timestamp of the event start or end
      #    result     (analysis_jobs_item_result)   -- (optional) the analysis result type
      #
      #  emits columns:
      #    next_event_time (timestamp without time zone) -- the timestamp of the next event in the group
      #    running_sum     (bigint)                      -- the number of concurrent/overlapping events at `event_time`
      #
      class TrackEventChanges < Cte::NodeTemplate
        table_name :track_event_changes
        dependencies stacked_temporal_events: Report::Ctes::Coverage::StackedTemporalEvents

        select do
          window_partitions = [stacked_temporal_events[:group_id]]
          window_partitions.unshift(stacked_temporal_events[:result]) if options[:analysis_result]

          window_lead = Arel::Nodes::Window.new
            .partition(*window_partitions)
            .order(stacked_temporal_events[:event_time])

          window_sum = Arel::Nodes::Window.new
            .partition(*window_partitions)
            .order(stacked_temporal_events[:event_time], stacked_temporal_events[:delta].desc)

          fields = [
            stacked_temporal_events[:group_id],
            stacked_temporal_events[:event_time],
            Arel::Nodes::NamedFunction.new('LEAD',
              [stacked_temporal_events[:event_time]]).over(window_lead).as('next_event_time'),
            Arel::Nodes::NamedFunction.new('SUM', [stacked_temporal_events[:delta]]).over(window_sum).as('running_sum')
          ]
          fields.unshift(stacked_temporal_events[:result]) if options[:analysis_result]

          stacked_temporal_events.project(*fields)
        end
      end
    end
  end
end
