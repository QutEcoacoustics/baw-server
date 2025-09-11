# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      # Generates a histogram of scores for audio events, grouped by tag and provenance.
      #
      # Score histogram binning steps
      # score_bins: Bin scores into 50 buckets for each tag/provenance
      # score_bin_fractions: Calculate fraction of scores in each bin
      # bin_series: Generate complete series of bins for each tag/provenance (CROSS JOIN)
      # bin_series_scores: Aggregate bin fractions into arrays
      # scores are binned into 50 buckets for unique tag/provenance
      class ScoreHistogram < Report::Cte::NodeTemplate
        table_name :score_histogram
        dependencies base_table: Report::Ctes::BaseEventReport

        SCORE_BINS = 50

        select do
          width_bucket = Arel::Nodes::NamedFunction.new('width_bucket', [
            base_table[:score],
            base_table[:provenance_score_minimum],
            base_table[:provenance_score_maximum],
            SCORE_BINS
          ])

          window = Arel::Nodes::Window.new.partition(
            base_table[:tag_id], base_table[:provenance_id]
          )

          base_table.project(
            base_table[:tag_id],
            base_table[:provenance_id],
            width_bucket.dup.as('bin_id'), # dup because 'as' mutates the object
            base_table[:audio_event_id].count.as('bin_count'),
            base_table[:audio_event_id].count.over(window).as('group_count')
          ).group(
            base_table[:tag_id],
            base_table[:provenance_id],
            base_table[:audio_event_id],
            width_bucket
          )
        end
      end
    end
  end
end
