# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Calculates the total duration of actual event coverage within each
      # coverage interval. Used later to determine coverage density.
      #
      # This CTE sums the durations of all sub-intervals where at least one
      # event is active (`running_sum` > 0). It measures the "real" coverage
      # within a group (coverage interval), excluding any gaps.
      #
      # == query output
      #
      #  emits columns:
      #    group_id (bigint)                  -- interval group id
      #    total_covered_seconds (numeric)    -- the total 'actual' coverage in seconds for the group
      #    result (analysis_jobs_item_result) -- (optional) if analysis_result is true, the analysis result
      #
      #  emits rows: one per group
      class EventCoverage < Cte::NodeTemplate
        table_name :event_coverage
        dependencies track_event_changes: Report::Ctes::Coverage::TrackEventChanges

        select do
          next_event_time = Arel::Nodes::SqlLiteral.new('next_event_time')
          event_time = Arel::Nodes::SqlLiteral.new('event_time')

          covered_seconds = Arel::Nodes::Subtraction.new(next_event_time, event_time).extract('epoch').sum

          group_by_fields = [track_event_changes[:group_id]]
          group_by_fields.unshift(track_event_changes[:result]) if options[:analysis_result]

          fields = [track_event_changes[:group_id], covered_seconds.as('total_covered_seconds')]
          fields.unshift(track_event_changes[:result]) if options[:analysis_result]

          track_event_changes.project(*fields).where(
           track_event_changes[:running_sum].gt(0)
             .and(track_event_changes[:next_event_time].not_eq(nil))
         ).group(*group_by_fields)
        end
      end
    end
  end
end
