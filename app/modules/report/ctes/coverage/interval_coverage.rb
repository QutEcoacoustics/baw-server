# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Defines a CTE that calculates the start and end times for each
      # continuous interval of temporal events.
      #
      # It groups the events by the `group_id` from the {CategoriseIntervals} CTE
      # and finds the minimum start time and maximum end time for each group.
      # This effectively collapses the individual events within a continuous
      # sequence into a single row representing the entire interval.
      #
      # If the `analysis_result` option is true, it also groups by the `result`
      # column, creating separate intervals for each analysis result type.
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
