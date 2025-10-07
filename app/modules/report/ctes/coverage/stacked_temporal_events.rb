# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Defines a CTE that stacks all start and end times of temporal events
      # into a single timeline, marking each time point with a `delta` value of
      # +1 for starts and -1 for ends. Periods where the `running_sum` of
      # `delta` values is greater than 0 indicate that at least one event is
      # active.
      #
      # @note This node doesn't execute directly with the current {Report::Cte::Node#execute} helper
      # @example To manually execute the stand-alone CTE node
      #   ci = Report::Ctes::Coverage::StackedTemporalEvents.new(options: params)
      #   cov = ci.select_manager.as('cov')
      #   ActiveRecord::Base.connection.execute(Arel::SelectManager.new.project(Arel.star).from(cov).with(ci.collect(root: false).map(&:node)).to_sql)
      class StackedTemporalEvents < Cte::NodeTemplate
        table_name :stacked_temporal_events
        dependencies categorise_intervals: Report::Ctes::Coverage::CategoriseIntervals

        # @return [ArelExtensions::Nodes::UnionAll]
        select do
          top = [
            categorise_intervals[:group_id],
            categorise_intervals[:start_time].as('event_time'),
            Arel::Nodes.build_quoted(1).as('delta')
          ]
          top << categorise_intervals[:result].as('result') if options[:analysis_result]

          bottom = [
            categorise_intervals[:group_id],
            categorise_intervals[:end_time].as('event_time'),
            Arel::Nodes.build_quoted(-1).as('delta')
          ]
          bottom << categorise_intervals[:result].as('result') if options[:analysis_result]

          categorise_intervals.project(top).union_all(categorise_intervals.project(bottom))
        end
      end
    end
  end
end
