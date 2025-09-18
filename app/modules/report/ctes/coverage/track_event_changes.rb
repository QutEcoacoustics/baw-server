# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # calculate the running sum of the delta values for each group
      # when the delta is positive there is an event active within the group
      # when the delta is 0 it indicates a gap in the group
      class TrackEventChanges < Cte::NodeTemplate
        # project the 'next_event_time' field, which will be used to calculate the
        # duration of events and groups
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
            # stacked_temporal_events[:running_sum]
          ]
          fields.unshift(stacked_temporal_events[:result]) if options[:analysis_result]

          stacked_temporal_events.project(*fields)
        end
      end
    end
  end
end
