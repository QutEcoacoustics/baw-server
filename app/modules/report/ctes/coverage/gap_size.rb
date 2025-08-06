# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      class GapSize < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :calculate_gap_size

        default_options start_time: nil, end_time: nil, scaling_factor: nil

        select do
          start_time, end_time, scaling_factor = options.values_at(:start_time, :end_time, :scaling_factor)
          report_range = Report::TimeSeries.arel_project_ts_range(start_time, end_time)
          report_range_interval = range_interval(report_range, scaling_factor)

          Arel::SelectManager.new
            .project(report_range_interval.as('gap_size'))
            .from(report_range)
        end

        def self.range_interval(report_range, scaling_factor)
          upper_epoch = Report::TimeSeries.upper(report_range[:range]).extract('epoch')
          lower_epoch = report_range[:range].lower.extract('epoch')

          seconds = upper_epoch - lower_epoch
          scaled_seconds = seconds / scaling_factor

          arel_seconds_to_interval(scaled_seconds)
        end

        def self.arel_seconds_to_interval(seconds)
          Arel::Nodes::NamedFunction.new(
            'make_interval',
            [Arel.sql('secs => ?', seconds)]
          )
        end
      end

      # Return a cte with fields for start, end, and previous end time Rows are
      # sorted based on the lower_field (start time) previous end time is a
      # derived column (null for the first row) representing the end_time of the
      # previous row
      class SortWithLag < Report::Cte::Node
        include Report::Cte::Dsl

        table_name :sort_with_lag

        depends_on source: BaseEventReport

        # lower and upper field are the attribute names of timestamp columns on
        # the `source` table dependency that will be used to calculate coverage
        default_options do
          {
            analysis_result: false,
            lower_field: nil,
            upper_field: nil
          }
        end

        select do
          analysis_result = options.fetch(:analysis_result)
          # time_lower, time_upper = options.values_at(:lower_field, :upper_field)
          time_lower = source[options[:lower_field]]
          time_upper = source[options[:upper_field]]

          window = build_window(
            partition_by: analysis_result ? source[:result] : nil,
            sort_by: time_lower
          )

          lag = build_lag(time_upper, window)
          fields = sort_with_lag_fields(time_lower, time_upper, lag, result: analysis_result ? source[:result] : nil)
          source.project(fields)
          # Arel::SelectManager.new.project(fields).from(source)
        end

        def self.build_window(sort_by:, partition_by: nil)
          window = Arel::Nodes::Window.new
          window = window.partition(partition_by) if partition_by
          window.order(sort_by)
        end

        def self.build_lag(column, window)
          Arel::Nodes::NamedFunction.new('LAG', [column]).over(window)
        end

        def self.sort_with_lag_fields(time_lower, time_upper, lag, result: nil)
          fields = [time_lower.as('start_time'), time_upper.as('end_time'), lag.as('prev_end')]
          fields.append(result.as('result')) if result
          fields
        end
      end

      # categorise each row into a group, starting from 0.
      # group id is incremented by 1 when the start time is greater than the
      # previous end time + gap size
      class Grouped < Report::Cte::Node
        include Report::Cte::Dsl

        table_name :grouped

        depends_on sorted_with_lag: Report::Ctes::Coverage::SortWithLag,
          gap_size_table: Report::Ctes::Coverage::GapSize

        select do
          cross_join = Arel::Nodes::SqlLiteral.new("CROSS JOIN #{gap_size_table.name} as gap")

          group_id_sql = if options[:analysis_result]
                           arel_group_id_case_statement_by_result
                         else
                           arel_group_id_case_statement
                         end

          sorted_with_lag.project(Arel.star, group_id_sql).join(cross_join)
        end

        def self.arel_group_id_case_statement
          # ? building the case statement in arel was causing postgres transaction
          #   fails? arel version => 'WHEN sorted_recordings.start_time >
          #   sorted_recordings.prev_end'
          #   but no table alias 'WHEN start_time > prev_end' works
          Arel.sql(
              <<~SQL.squish
                SUM(CASE WHEN start_time > prev_end + gap.gap_size THEN 1 ELSE 0 END)
                OVER (ORDER BY start_time) AS group_id
              SQL
            )
        end

        def self.arel_group_id_case_statement_by_result
          Arel.sql(
              <<~SQL.squish
                SUM(CASE WHEN start_time > prev_end + gap.gap_size THEN 1 ELSE 0 END)
                OVER (PARTITION BY result ORDER BY start_time) AS group_id
              SQL
            )
        end
      end

      class CoverageIntervals < Report::Cte::Node
        include Report::Cte::Dsl

        table_name :coverage_intervals
        depends_on grouped: Report::Ctes::Coverage::Grouped

        select do
          fields = [
            grouped[:group_id],
            grouped[:start_time].minimum.as('coverage_start'),
            grouped[:end_time].maximum.as('coverage_end')
          ]
          fields << grouped[:result].as('result') if options[:analysis_result]
          group_by_fields = [grouped[:group_id]]
          group_by_fields.unshift(grouped[:result]) if options[:analysis_result]

          grouped.project(fields).group(*group_by_fields)
        end
      end

      class CoverageEvents < Report::Cte::Node
        include Report::Cte::Dsl

        table_name :coverage_events
        depends_on grouped: Report::Ctes::Coverage::Grouped

        # sweep line approach
        select do
          top = [
            grouped[:group_id],
            grouped[:start_time].as('event_time'),
            Arel::Nodes.build_quoted(1).as('delta')
          ]
          top << grouped[:result].as('result') if options[:analysis_result]

          bottom = [
            grouped[:group_id],
            grouped[:end_time].as('event_time'),
            Arel::Nodes.build_quoted(-1).as('delta')
          ]
          bottom << grouped[:result].as('result') if options[:analysis_result]

          # returns a class ArelExtensions::Nodes::UnionAll
          # this Report::Cte::Node doesn't #execute directly, it only works
          # as a CTE.
          grouped.project(top).union_all(grouped.project(bottom))
        end
      end

      # calculate the running sum of the delta values for each group
      # when the delta is positive there is an event active within the group
      # when the delta is 0 it indicates a gap in the group
      class CoverageEventsSortedSum < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :coverage_events_sorted_sum
        depends_on coverage_events: Report::Ctes::Coverage::CoverageEvents

        select do
          window_partitions = [coverage_events[:group_id]]
          window_partitions.unshift(coverage_events[:result]) if options[:analysis_result]

          window = Arel::Nodes::Window.new
            .partition(*window_partitions)
            .order(coverage_events[:event_time], coverage_events[:delta].desc)

          fields = [
            coverage_events[:group_id],
            coverage_events[:event_time],
            Arel::Nodes::NamedFunction.new('SUM', [coverage_events[:delta]]).over(window).as('running_sum')
          ]
          fields.unshift(coverage_events[:result]) if options[:analysis_result]

          coverage_events.project(*fields)
        end
      end

      class CoveredIntervals < Report::Cte::Node
        include Report::Cte::Dsl
        # project the 'next_event_time' field, which will be used to calculate the
        # duration of events and groups
        table_name :covered_intervals
        depends_on coverage_events_sorted_sum: Report::Ctes::Coverage::CoverageEventsSortedSum

        select do
          window_partitions = [coverage_events_sorted_sum[:group_id]]
          window_partitions.unshift(coverage_events_sorted_sum[:result]) if options[:analysis_result]

          window = Arel::Nodes::Window.new
            .partition(*window_partitions)
            .order(coverage_events_sorted_sum[:event_time])

          fields = [
            coverage_events_sorted_sum[:group_id],
            coverage_events_sorted_sum[:event_time],
            Arel::Nodes::NamedFunction.new('LEAD',
              [coverage_events_sorted_sum[:event_time]]).over(window).as('next_event_time'),
            coverage_events_sorted_sum[:running_sum]
          ]
          fields.unshift(coverage_events_sorted_sum[:result]) if options[:analysis_result]

          coverage_events_sorted_sum.project(*fields)
        end
      end

      # within each group, get the sum of the durations of all the events an
      # event is either a start or end time, and next_end_time does not
      # necessarily correspond to a separate row in the context of the original
      # data e.g. event time 0 and next_event_time 10 could represent a start
      # and end time of a single recording, or two separate recordings.
      # Added options hash
      class CoveredDurations < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :covered_durations
        depends_on covered_intervals: Report::Ctes::Coverage::CoveredIntervals

        select do
          next_event_time = Arel::Nodes::SqlLiteral.new('next_event_time')
          event_time = Arel::Nodes::SqlLiteral.new('event_time')

          covered_seconds = Arel::Nodes::Subtraction.new(next_event_time, event_time).extract('epoch').sum

          group_by_fields = [covered_intervals[:group_id]]
          group_by_fields.unshift(covered_intervals[:result]) if options[:analysis_result]

          fields = [covered_intervals[:group_id], covered_seconds.as('total_covered_seconds')]
          fields.unshift(covered_intervals[:result]) if options[:analysis_result]

          covered_intervals.project(*fields).where(
           covered_intervals[:running_sum].gt(0)
             .and(covered_intervals[:next_event_time].not_eq(nil))
         ).group(*group_by_fields)
        end
      end

      class FinalCoverage < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :final_coverage
        depends_on coverage_intervals: Report::Ctes::Coverage::CoverageIntervals,
          covered_durations: Report::Ctes::Coverage::CoveredDurations

        select do
          fields = [
            coverage_intervals[:group_id],
            coverage_intervals[:coverage_start],
            coverage_intervals[:coverage_end],
            covered_durations[:total_covered_seconds],
            Arel::Nodes::Subtraction.new(
              coverage_intervals[:coverage_end],
              coverage_intervals[:coverage_start]
            ).extract('epoch').as('interval_seconds'),
            Arel::Nodes::Division.new(
              covered_durations[:total_covered_seconds],
              Arel::Nodes::Subtraction.new(
                coverage_intervals[:coverage_end],
                coverage_intervals[:coverage_start]
              ).extract('epoch')
            ).as('density')
          ]
          fields.unshift(coverage_intervals[:result]) if options[:analysis_result]
          select = coverage_intervals.project(*fields)

          if options[:analysis_result]
            select.join(covered_durations, Arel::Nodes::OuterJoin)
              .on(coverage_intervals[:result].eq(covered_durations[:result])
                         .and(coverage_intervals[:group_id].eq(covered_durations[:group_id])))
              .order(coverage_intervals[:result], coverage_intervals[:group_id])
          else
            select.join(covered_durations, Arel::Nodes::OuterJoin)
              .on(coverage_intervals[:group_id].eq(covered_durations[:group_id]))
              .order(coverage_intervals[:group_id])
          end
        end
      end

      class Coverage < Report::Cte::Node
        include Report::Cte::Dsl

        table_name :coverage
        depends_on final_coverage: Report::Ctes::Coverage::FinalCoverage
        default_options project_field_as: 'coverage', analysis_result: false

        select do
          # Return an Arel::SelectManager that projects the aggregated coverage
          # result. To execute the query, all dependency CTEs must be included in
          # a `.with` clause
          #
          # @param [Report::TableExpression::Collection] coverage collection
          # @param [Hash] options, Report::Section::Coverage options
          # @return [Arel::SelectManager]
          # TODO: some kind of root plus suffix matching logic?
          range = Report::TimeSeries.arel_tsrange(final_coverage[:coverage_start], final_coverage[:coverage_end])

          fields = { 'range' => range,
                     'density' => final_coverage[:density].round(3) }

          fields = fields.merge('type' => final_coverage[:result]) if options[:analysis_result]

          json = Arel.json(fields)

          project_field_as = options[:project_field_as]

          # maybe just make this a fixed string
          # and then in the report Cte you are writing the aliases you want anyway
          final_coverage
            .project(json.json_agg.as(project_field_as.to_s))
        end
      end
    end
  end
end
