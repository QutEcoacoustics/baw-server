# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Defines a CTE that returns the start and end time for each grouping
      # (interval) of temporal events.
      #
      # == query output
      #
      #  emits columns:
      #    group_id       (bigint)                      -- sequential group index, 0-based
      #    coverage_start (timestamp without time zone) -- the start time of the continuous interval
      #    coverage_end   (timestamp without time zone) -- the end time of the continuous interval
      #    result         (analysis_jobs_item_result)   -- (optional) the analysis result type
      #
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
