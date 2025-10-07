# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      #
      # Root CTE for an event summary report.
      #
      # Defines a CTE that formats the results of {EventSummaryJson} into a
      # JSON array representing the event summaries. This is the final step in
      # the event summary report generation.
      #
      # == query output
      #
      #  emits column:
      #    event_summaries (json) -- an array of event summary objects
      #
      #  emits json fields in event_summaries[*]:
      #    provenance_id (int) -- the id of the provenance
      #    tag_id (int) -- the id of the tag
      #    events (json) -- a json object containing event statistics
      #    score_histogram (json) -- a json object containing score histogram data
      #
      # @example Basic usage
      #   result = Report::Ctes::EventSummary::EventSummary.execute
      #   series = Report::Ctes::EventSummary::EventSummary.format_result(result.first)
      #
      class EventSummary < Cte::NodeTemplate
        table_name :event_summary

        dependencies event_summary_json: Report::Ctes::EventSummary::EventSummaryJson

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
