# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      # calculate the fraction of scores in each bin, relative to the total for that tag/provenance group
      class ScoreBinFractions < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :score_bin_fractions
        depends_on score_bins: Report::Ctes::EventSummary::ScoreHistogram
        select do
          null_if_count = null_if(score_bins[:group_count], 0)
          score_bins.project(
            score_bins[:tag_id],
            score_bins[:provenance_id],
            score_bins[:bin_id],
            score_bins[:bin_count],
            score_bins[:group_count],
            (score_bins[:bin_count].cast('numeric') / null_if_count).round(3).as('bin_fraction')
          )
        end

        def self.null_if(column, value)
          Arel::Nodes::NamedFunction.new 'NULLIF', [column, value]
        end
      end
    end
  end
end
