# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      # get the complete series of bins 1 to 50 for unique tag_id and provenance_id
      class BinSeries < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :bin_series
        depends_on base_table: Report::Ctes::BaseEventReport
        select do
          generate_series = Report::TimeSeries.generate_series(50).as('bin_id')
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
