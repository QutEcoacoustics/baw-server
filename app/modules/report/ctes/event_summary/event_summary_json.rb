# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      # Aggregate all results into event_summaries JSON for reporting
      # Each row is a tag/provenance summary with event and score histogram data
      class EventSummaryJson < Report::Cte::NodeTemplate
        table_name :event_summary_json
        dependencies event_summary_statistics: Report::Ctes::EventSummary::EventSummaryStatistics,
          bin_series_scores: Report::Ctes::EventSummary::BinSeriesScores
        select do
          # NOTE: the event_summaries are tag + audio_event (tagging) centric;
          # each summary datum for a tag has a count of events. since it's
          # possible to have more one tagging for an event, an event associated
          # with more than one tag will be counted more than once (across the
          # series). I.e., the 'count' fields, when summed across all
          # event_summaries, will equal the length of taggings.
          events_json = event_summary_counts_and_consensus_as_json(event_summary_statistics)
          scores_json = score_histogram_as_json(event_summary_statistics, bin_series_scores)

          event_summary_statistics.project(
            event_summary_statistics[:provenance_id],
            event_summary_statistics[:tag_id],
            events_json.as('events'),
            scores_json.as('score_histogram')
          ).group(
            event_summary_statistics[:tag_id],
            event_summary_statistics[:provenance_id]
          ).join(bin_series_scores, Arel::Nodes::OuterJoin)
            .on(event_summary_statistics[:tag_id].eq(bin_series_scores[:tag_id])
            .and(event_summary_statistics[:provenance_id].eq(bin_series_scores[:provenance_id])))
        end

        def self.event_summary_counts_and_consensus_as_json(source)
          Arel.json({
            count: source[:count],
            verifications: source[:verifications],
            consensus: source[:consensus]
          }).group # => jsonb_agg(jsonb_build_object (...))
        end

        def self.score_histogram_as_json(source, score_bins_table)
          Arel.json({
            bins: score_bins_table[:bin_fraction],
            standard_deviation: source[:score_stdev].round(3),
            mean: source[:score_mean].round(3),
            min: source[:score_min],
            max: source[:score_max]
          }).group # => jsonb_agg(jsonb_build_object (...))
        end
      end
    end
  end
end
