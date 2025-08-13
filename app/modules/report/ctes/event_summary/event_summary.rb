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
      end
    end
  end
end
