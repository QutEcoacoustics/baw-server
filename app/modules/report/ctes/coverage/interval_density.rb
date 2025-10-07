# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Defines a CTE that calculates the density of event coverage within each
      # continuous interval.
      #
      # It joins the `interval_coverage` CTE (which defines the bounds of each
      # interval) with the `event_coverage` CTE (which calculates the total
      # duration of actual event coverage within each interval).
      #
      # The density is calculated as the ratio of the total covered seconds to
      # the total duration of the interval. A density of 1.0 means the interval
      # is completely covered by events, while a density less than 1.0 indicates
      # gaps.
      #
      # If the `analysis_result` option is true, density is calculated separately
      # for each analysis result type.
      #
      # == query output
      #
      #  inherits columns from `interval_coverage`:
      #    group_id       (bigint)                       -- sequential group index, 0-based
      #    coverage_start (timestamp without time zone)  -- the start time of the continuous interval
      #    coverage_end   (timestamp without time zone)  -- the end time of the continuous interval
      #    result         (analysis_jobs_item_result)    -- (optional) the analysis result type
      #
      #  inherits columns from `event_coverage`:
      #    total_covered_seconds (numeric) -- total duration of actual event coverage within the interval
      #
      #  emits columns:
      #    interval_seconds (numeric) -- total duration of the interval
      #    density          (numeric) -- ratio of covered seconds to interval seconds (0.0 to 1.0)
      #
      class IntervalDensity < Cte::NodeTemplate
        table_name :interval_density
        dependencies interval_coverage: Report::Ctes::Coverage::IntervalCoverage,
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
              .order(interval_coverage[:result], interval_coverage[:group_id])
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
