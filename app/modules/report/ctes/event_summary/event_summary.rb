# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      class EventSummary < Report::Cte::Node
        include Report::Cte::Dsl

        table_name :event_summary

        depends_on event_summary_json: Report::Ctes::EventSummary::EventSummaryJson

        select do
          event_summaries_aliased = event_summary_json.as('e')
          Arel::SelectManager.new
            .project(event_summaries_aliased.right.json_agg.as('event_summaries'))
            .from(event_summaries_aliased)
        end

        def self.format_result(result, base_key = 'event_summaries', suffix: nil)
          key = suffix ? "#{base_key}_#{suffix}" : base_key

          transform_event_summary = lambda { |item|
            events_data = item['events'].first
            events_data.merge!('consensus' => events_data['consensus'].round(3)) if events_data['consensus']

            item.merge('events' => events_data)
          }

          Decode.json result[key], &transform_event_summary
        end
      end
    end
  end
end
