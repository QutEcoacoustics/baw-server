# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      class IntervalDensity < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :interval_density
        depends_on interval_coverage: Report::Ctes::Coverage::IntervalCoverage,
          event_coverage: Report::Ctes::Coverage::EventCoverage

        select do
          fields = [
            interval_coverage[:group_id],
            interval_coverage[:coverage_start],
            interval_coverage[:coverage_end],
            event_coverage[:total_covered_seconds],
            Arel::Nodes::Subtraction.new(
              interval_coverage[:coverage_end],
              interval_coverage[:coverage_start]
            ).extract('epoch').as('interval_seconds'),
            Arel::Nodes::Division.new(
              event_coverage[:total_covered_seconds],
              Arel::Nodes::Subtraction.new(
                interval_coverage[:coverage_end],
                interval_coverage[:coverage_start]
              ).extract('epoch')
            ).as('density')
          ]
          fields.unshift(interval_coverage[:result]) if options[:analysis_result]
          select = interval_coverage.project(*fields)

          if options[:analysis_result]
            select.join(event_coverage, Arel::Nodes::OuterJoin)
              .on(interval_coverage[:result].eq(event_coverage[:result])
                         .and(interval_coverage[:group_id].eq(event_coverage[:group_id])))
              .order(interval_coverage[:result], coverage_intervals[:group_id])
          else
            select.join(event_coverage, Arel::Nodes::OuterJoin)
              .on(interval_coverage[:group_id].eq(event_coverage[:group_id]))
              .order(interval_coverage[:group_id])
          end
        end
      end
    end
  end
end
