# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # returns a class ArelExtensions::Nodes::UnionAll
      # this Report::Cte::Node doesn't #execute directly, it only works
      # as a CTE.
      # could add handling on Node for executing this return type
      # example of how to manually execute:
      # ci = Report::Ctes::Coverage::CoverageEvents.new(options: params)
      # cov = ci.select_manager.as('cov')
      # ActiveRecord::Base.connection.execute(Arel::SelectManager.new.project(Arel.star).from(cov).with(ci.collect(root: false).map(&:node)).to_sql)
      class StackedTemporalEvents < Cte::NodeTemplate
        table_name :stacked_temporal_events
        dependencies categorise_intervals: Report::Ctes::Coverage::CategoriseIntervals

        # stack all start and end times into a single column
        # add a column 'delta' with value 1 for start times and -1 for end times
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
