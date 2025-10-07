# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      #
      # Aggregates score bin fractions into an array for each tag/provenance group.
      #
      # This CTE joins the complete series of bins from {BinSeries} with the
      # calculated bin fractions from {ScoreBinFractions}. It coalesces missing
      # bin fractions to 0 and aggregates them into a single array, ensuring a
      # complete histogram data series.
      #
      # == query output
      #
      #  emits columns:
      #    tag_id (int) -- the id of the tag
      #    provenance_id (int) -- the id of the provenance
      #    bin_fraction (array[numeric]) -- an array of bin fractions for the histogram
      #
      class BinSeriesScores < Cte::NodeTemplate
        table_name :bin_series_scores
        dependencies bin_series: Report::Ctes::EventSummary::BinSeries,
          score_bin_fractions: Report::Ctes::EventSummary::ScoreBinFractions

        select do
          # aggregate bin fractions into arrays, coalescing missing bins to 0
          coalesce = Arel::Nodes::NamedFunction.new('COALESCE', [score_bin_fractions[:bin_fraction], 0])

          bin_series.project(
            bin_series[:tag_id],
            bin_series[:provenance_id],
            coalesce.array_agg.as('bin_fraction')
          ).join(score_bin_fractions, Arel::Nodes::OuterJoin)
            .on(
            Arel::Nodes::And.new([
              bin_series[:tag_id].eq(score_bin_fractions[:tag_id]),
              bin_series[:provenance_id].eq(score_bin_fractions[:provenance_id]),
              bin_series[:bin_id].eq(score_bin_fractions[:bin_id])
            ])
          ).group(bin_series[:tag_id], bin_series[:provenance_id])
        end
      end
    end
  end
end
