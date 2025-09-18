# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Project the minimum start and maximum end time for each interval group
      # If analysis_result is true, group by result and project result field
      class IntervalCoverage < Cte::NodeTemplate
        table_name :interval_coverage
        dependencies categorise_intervals: Report::Ctes::Coverage::CategoriseIntervals

        select do
          fields = [
            categorise_intervals[:group_id],
            categorise_intervals[:start_time].minimum.as('coverage_start'),
            categorise_intervals[:end_time].maximum.as('coverage_end')
          ]
          fields << categorise_intervals[:result].as('result') if options[:analysis_result]
          group_by_fields = [categorise_intervals[:group_id]]
          group_by_fields.unshift(categorise_intervals[:result]) if options[:analysis_result]

          categorise_intervals.project(fields).group(*group_by_fields)
        end
      end
    end
  end
end
