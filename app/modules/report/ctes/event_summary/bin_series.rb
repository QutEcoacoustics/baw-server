# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      #
      # Generates a complete series of bins for each tag/provenance combination.
      #
      # This CTE creates a row for each bin from 1 to 50 for every unique
      # tag_id and provenance_id pair found in the base event report. This ensures
      # that the score histogram has a value for every bin, even if it's zero.
      #
      # == query output
      #
      #  emits columns:
      #    tag_id (int) -- the id of the tag
      #    provenance_id (int) -- the id of the provenance
      #    bin_id (int) -- the bin number (1 to 50)
      #
      class BinSeries < Cte::NodeTemplate
        table_name :bin_series
        dependencies base_table: Report::Ctes::BaseEventReport
        select do
          generate_series = Report::TimeSeries.generate_series(ScoreHistogram::SCORE_BINS).as('bin_id')
          cross_join = Arel::Nodes::StringJoin.new(Arel.sql('CROSS JOIN ?', generate_series))

          distinct_tag_provenance = base_table.dup
            .project(base_table[:tag_id], base_table[:provenance_id])
            .distinct
            .as('distinct_tag_provenance')

          # include distinct_tag_provenance as a subquery
          select = Arel::SelectManager.new.project(
            distinct_tag_provenance[:tag_id],
            distinct_tag_provenance[:provenance_id],
            generate_series.right
          ).from(distinct_tag_provenance)

          select.join_sources << cross_join
          select
        end
      end
    end
  end
end
