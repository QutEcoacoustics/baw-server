# frozen_string_literal: true

module Report
  module Section
    module Coverage
      extend ::Report::Section

      module_function

      # ! hack this entire module runs twice - once for recordings, and again
      #   for analysis result. the :analysis_result field in options is used to
      #   special case cte creation within the methods, until we have a better
      #   solution like a postgres function. this is also the reason :suffix
      #   exists - ctes need unique names. See Report::Section::Step#suffix

      # ? TimeSeries.Options also required to run Coverage but this is opaque
      # @param time_series_options [Hash] additional options to be merged
      def options(time_series_options)
        options = {
          source: nil,
          lower_field: nil,
          upper_field: nil,
          analysis_result: nil,
          project_field_as: 'coverage',
          suffix: nil
        }

        yield(options) if block_given?
        options.compact.merge(time_series_options)
      end

      TABLE_GAP_SIZE = Arel::Table.new('gap_size')
      TABLE_SORT_WITH_LAG = Arel::Table.new('sort_with_lag')
      TABLE_GROUPED = Arel::Table.new('grouped')
      TABLE_COVERAGE_INTERVALS = Arel::Table.new('coverage_intervals')
      TABLE_COVERAGE_EVENTS = Arel::Table.new('coverage_events')
      TABLE_COVERAGE_EVENTS_SORTED_SUM = Arel::Table.new('coverage_events_sorted_sum')
      TABLE_COVERED_INTERVALS = Arel::Table.new('covered_intervals')
      TABLE_COVERED_DURATIONS = Arel::Table.new('covered_durations')
      TABLE_FINAL_COVERAGE = Arel::Table.new('final_coverage')

      TABLES = {
        gap_size: TABLE_GAP_SIZE,
        sort_with_lag: TABLE_SORT_WITH_LAG,
        grouped: TABLE_GROUPED,
        coverage_intervals: TABLE_COVERAGE_INTERVALS,
        coverage_events: TABLE_COVERAGE_EVENTS,
        coverage_events_sorted_sum: TABLE_COVERAGE_EVENTS_SORTED_SUM,
        covered_intervals: TABLE_COVERED_INTERVALS,
        covered_durations: TABLE_COVERED_DURATIONS,
        final_coverage: TABLE_FINAL_COVERAGE
      }.freeze

      step table: TABLE_GAP_SIZE, as: proc { |_t, options|
        # report boundaries
        calculate_gap_size(options)
      }

      step table: TABLE_SORT_WITH_LAG, as: proc { |_t, options|
        sort_with_lag(options)
      }

      step table: TABLE_GROUPED, depends_on: [TABLE_SORT_WITH_LAG, TABLE_GAP_SIZE], as: proc { |_t, *depends_on, options|
        sorted_with_lag, gap_size_table = depends_on
        grouped(sorted_with_lag, gap_size_table, options)
      }

      step table: TABLE_COVERAGE_INTERVALS, depends_on: TABLE_GROUPED, as: proc { |_t, grouped, options|
        coverage_intervals(grouped, options)
      }

      step table: TABLE_COVERAGE_EVENTS, depends_on: TABLE_GROUPED, as: proc { |_t, grouped, options|
        coverage_events(grouped, options)
      }
      step table: TABLE_COVERAGE_EVENTS_SORTED_SUM, depends_on: TABLE_COVERAGE_EVENTS, as: proc { |_t, events, options|
        coverage_events_sorted_sum(events, options)
      }
      step table: TABLE_COVERED_INTERVALS, depends_on: TABLE_COVERAGE_EVENTS_SORTED_SUM, as: proc { |_t, events_sum, options|
        covered_intervals(events_sum, options)
      }
      step table: TABLE_COVERED_DURATIONS, depends_on: TABLE_COVERED_INTERVALS, as: proc { |_t, intervals, options|
        covered_durations(intervals, options)
      }
      step table: TABLE_FINAL_COVERAGE, depends_on: [TABLE_COVERAGE_INTERVALS, TABLE_COVERED_DURATIONS], as: proc { |_t, *depends_on, options|
        coverage_intervals, covered_durations = depends_on
        final_coverage(coverage_intervals, covered_durations, options)
      }

      # Return an Arel::SelectManager that projects the aggregated coverage
      # result. To execute the query, all dependency CTEs must be included in
      # a `.with` clause
      #
      # @param [Report::TableExpression::Collection] coverage collection
      # @param [Hash] options, Report::Section::Coverage options
      # @return [Arel::SelectManager]
      def project(collection, options)
        coverage_json(collection, options)
      end

      def calculate_gap_size(options = {})
        lower, upper, scaling = options.values_at(:start_time, :end_time, :scaling_factor)
        report_range = Report::TimeSeries.arel_project_ts_range(
          options[:start_time], options[:end_time]
        )
        report_range_interval = range_interval(report_range, scaling)

        Arel::SelectManager.new
          .project(report_range_interval.as('gap_size'))
          .from(report_range)
      end

      # Return a cte with fields for start, end, and previous end time Rows are
      # sorted based on the lower_field (start time) previous end time is a
      # derived column (null for the first row) representing the end_time of the
      # previous row
      def sort_with_lag(options = {})
        source, analysis_result = options.values_at(:source, :analysis_result)
        time_lower, time_upper = options.values_at(:lower_field, :upper_field)
        window = build_window(
          partition_by: analysis_result ? source[:result] : nil,
          sort_by: time_lower
        )

        lag = build_lag(time_upper, window)
        fields = sort_with_lag_fields(time_lower, time_upper, lag, result: analysis_result ? source[:result] : nil)
        Arel::SelectManager.new.project(fields).from(source)
      end

      def sort_with_lag_fields(time_lower, time_upper, lag, result: nil)
        fields = [time_lower.as('start_time'), time_upper.as('end_time'), lag.as('prev_end')]
        fields.append(result.as('result')) if result
        fields
      end

      # categorise each row into a group, starting from 0.
      # group id is incremented by 1 when the start time is greater than the
      # previous end time + gap size
      def grouped(sorted_with_lag, gap_size_table, options = {})
        cross_join = Arel::Nodes::SqlLiteral.new("CROSS JOIN #{gap_size_table.name} as gap")
        group_id_sql = if options[:analysis_result]
                         arel_group_id_case_statement_by_result
                       else
                         arel_group_id_case_statement
                       end
        sorted_with_lag.project(Arel.star, group_id_sql).join(cross_join)
      end

      def coverage_intervals(grouped, options = {})
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

      # sweep line approach
      def coverage_events(grouped, options = {})
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

        Arel::Nodes::Grouping.new(
            grouped.project(top).union_all(grouped.project(bottom))
          )
      end

      # calculate the running sum of the delta values for each group
      # when the delta is positive there is an event active within the group
      # when the delta is 0 it indicates a gap in the group
      def coverage_events_sorted_sum(coverage_events, options = {})
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

      # project the 'next_event_time' field, which will be used to calculate the
      # duration of events and groups
      def covered_intervals(coverage_events_sorted_sum, options = {})
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

      # within each group, get the sum of the durations of all the events an
      # event is either a start or end time, and next_end_time does not
      # necessarily correspond to a separate row in the context of the original
      # data e.g. event time 0 and next_event_time 10 could represent a start
      # and end time of a single recording, or two separate recordings.
      # Added options hash
      def covered_durations(covered_intervals, options = {})
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

      def final_coverage(coverage_intervals, covered_durations, options = {})
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

      def coverage_json(collection, options = {})
        # ! dodgy, still working around the suffix issue
        if collection.is_a?(Report::TableExpression::Collection)
          table_key = collection.entries.keys.grep(/final_coverage/).first
          final_coverage = collection.get(table_key).tables
        elsif collection.is_a?(Hash)
          table_key = collection.keys.grep(/final_coverage/).first
          final_coverage = collection[table_key][:table]
        else
          raise ArgumentError,
            "collection must be a Report::TableExpression::Collection or a Hash, got #{collection.class}"
        end

        range = Report::TimeSeries.arel_tsrange(final_coverage[:coverage_start], final_coverage[:coverage_end])

        fields = { 'range' => range,
                   'density' => final_coverage[:density].round(3) }
        fields = fields.merge('type' => final_coverage[:result]) if options[:analysis_result]

        json = Arel.json(fields)
        project_field_as = options[:project_field_as] || 'coverage'
        Arel::SelectManager.new.project(json.json_agg.as(project_field_as.to_s)).from(final_coverage)
      end

      def build_window(sort_by:, partition_by: nil)
        window = Arel::Nodes::Window.new
        window = window.partition(partition_by) if partition_by
        window.order(sort_by)
      end

      def build_lag(column, window)
        Arel::Nodes::NamedFunction.new('LAG', [column]).over(window)
      end

      def range_interval(report_range, scaling_factor)
        upper_epoch = TimeSeries.upper(report_range[:range]).extract('epoch')
        lower_epoch = report_range[:range].lower.extract('epoch')

        seconds = upper_epoch - lower_epoch
        scaled_seconds = seconds / scaling_factor

        arel_seconds_to_interval(scaled_seconds)
      end

      def arel_seconds_to_interval(seconds)
        Arel::Nodes::NamedFunction.new(
          'make_interval',
          [Arel.sql('secs => ?', seconds)]
        )
      end

      def arel_window_partition_result_sort(partition_by, sort_by)
        Arel::Nodes::Window.new.partition(partition_by).order(sort_by)
      end

      def arel_window_partition_sort(sort_by)
        Arel::Nodes::Window.new.order(sort_by)
      end

      def arel_group_id_case_statement
        # ? building the case statement in arel was causing postgres transaction
        #   fails? arel version => 'WHEN sorted_recordings.start_time >
        #   sorted_recordings.prev_end'
        #   but no table alias 'WHEN start_time > prev_end' works
        group_id = Arel.sql(
          <<~SQL.squish
            SUM(CASE WHEN start_time > prev_end + gap.gap_size THEN 1 ELSE 0 END)
            OVER (ORDER BY start_time) AS group_id
          SQL
        )
      end

      def arel_group_id_case_statement_by_result
        group_id = Arel.sql(
          <<~SQL.squish
            SUM(CASE WHEN start_time > prev_end + gap.gap_size THEN 1 ELSE 0 END)
            OVER (PARTITION BY result ORDER BY start_time) AS group_id
          SQL
        )
      end
    end
  end
end
