# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      #
      # Calculates the fraction of scores in each histogram bin.
      #
      # This CTE takes the binned score data from {ScoreHistogram} and calculates
      # the fraction of the total scores that fall into each bin for a given
      # tag/provenance group.
      #
      # == query output
      #
      #  emits columns:
      #    tag_id (int)            -- the id of the tag
      #    provenance_id (int)     -- the id of the provenance
      #    bin_id (int)            -- the bin number for the score
      #    bin_fraction (numeric)  -- the fraction of events in the bin, rounded to 3 decimal places
      #
      class ScoreBinFractions < Cte::NodeTemplate
        table_name :score_bin_fractions
        dependencies score_bins: Report::Ctes::EventSummary::ScoreHistogram
        select do
          null_if_count = null_if(score_bins[:group_count], 0)
          score_bins.project(
            score_bins[:tag_id],
            score_bins[:provenance_id],
            score_bins[:bin_id],
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
