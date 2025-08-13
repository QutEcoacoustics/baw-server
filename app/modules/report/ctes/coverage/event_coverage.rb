# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # within each group, get the sum of the durations of all the events
      # an event is either a start or end time, and next_end_time does not
      # necessarily correspond to a separate row in the context of the original
      # data e.g. event time 0 and next_event_time 10 could represent a start
      # and end time of a single recording, or two separate recordings.
      #
      # we want to know the duration of time covered by events within an interval
      class EventCoverage < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :event_coverage
        depends_on track_event_changes: Report::Ctes::Coverage::TrackEventChanges

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
