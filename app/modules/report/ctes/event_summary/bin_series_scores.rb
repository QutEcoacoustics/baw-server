# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      class BinSeriesScores < Report::Cte::NodeTemplate
        table_name :bin_series_scores
        depdendencies bin_series: Report::Ctes::EventSummary::BinSeries,
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
