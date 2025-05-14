# frozen_string_literal: true

module Report
  module TimeSeries
    # Module for generating coverage series CTEs. This module provides methods
    # to create a series of Common Table Expressions (CTEs) for generating a
    # temporal coverage report. Temporal coverage is reported as a series of
    # coverage objects, with a range value for the coveral interval. An interval
    # is a grouping of one or more temporal events. Events can be
    # non-overlapping - close proximity events are grouped according to a
    # scaling factor. The density or fractional coverage of each interval is
    # also reported.
    module Coverage
      module_function

      include Report::ArelHelpers
      extend Report::ArelHelpers

      # Creates coverage options specifying input table and columns to use when
      # generating a coverage series CTE.
      # @param source [Arel::Table] The source table containing fields to use
      # @param fields [Hash]
      #   :lower_field [Arel::Attributes::Attribute, Arel::Nodes::Node]
      #    field or expression representing the lower bound of a time period
      #   :upper_field [Arel::Attributes::Attribute, Arel::Nodes::Node]
      #    field or expression representing the upper bound of a time period
      # @return [Hash] A hash { source:, fields: { :lower_field, :upper_field }
      def coverage_options(source:, fields:)
        {
          source: source,
          fields: fields
        }
      end

      # Orchestrates a data-driven pipeline to construct a series of Arel-based
      # Common Table Expressions (CTEs) for generating a time series coverage report.
      #
      # Intent:
      # This method implements a pipeline pattern where each stage produces a CTE.
      # The `cte_structure` hash defines this pipeline:
      #   - Keys are symbolic names for CTE stages (and correspond to method names).
      #   - Values are arrays of symbolic names, representing the Arel table
      #     dependencies required by that stage.
      # This structure ensures dependencies are processed in topological order.
      #
      # Arel-Native CTE Methods:
      # Each method invoked (e.g., `grouped`, `coverage_intervals`) is designed to be
      # Arel-centric and pipeline-agnostic:
      #   - Signature: Accepts one or more `Arel::Table` objects as arguments.
      #   - Returns: An array `[Arel::Table, Arel::Nodes::As]`, representing the newly
      #     defined Arel table and its corresponding CTE node.
      #   - Agnostic: These methods operate purely on Arel constructs and have no
      #     knowledge of the `Report::Expression::Collection` or `Report::Expression::Cte`
      #     wrapper classes used by this pipeline orchestrator.
      #
      # Orchestration:
      # The `Report::Expression::Collection` manages the lifecycle of these Arel
      # constructs, storing each generated `Arel::Table` and its `Arel::Nodes::As`
      # (wrapped in an `Expression::Cte` object) and providing them as inputs to
      # subsequent stages based on the defined dependencies.
      #
      # @param time_series_options [Hash] Options for the overall time series.
      # @param coverage_options [Hash] Options specific to coverage calculation.
      # @return [Report::Expression::Collection] A collection of all generated
      # CTEs.
      def coverage_series(time_series_options, coverage_options)
        cte_structure = {
          grouped: [:sort_with_lag, :gap_size],
          coverage_intervals: [:grouped],
          coverage_events: [:grouped],
          coverage_events_sorted_sum: [:coverage_events],
          covered_intervals: [:coverage_events_sorted_sum],
          covered_durations: [:covered_intervals],
          final_coverage: [:coverage_intervals, :covered_durations]
        }

        collection = Report::Expression::Collection.new

        # for now these two aren't in the pipeline for simplicity as they follow
        # a different pattern.
        calculate_gap_size(time_series_options).tap do |table, cte|
          collection.add(:gap_size, Expression::Cte.new(table, cte))
        end

        sort_with_lag(coverage_options).tap do |table, cte|
          collection.add(:sort_with_lag, Expression::Cte.new(table, cte))
        end

        # For each key, pass the dependencies keys to collection to retrieve the
        # associated tables, to be passed as arguments to the method. from the
        # collection call the method with the dependencies
        cte_structure.each do |key, dependencies|
          table, cte = send(key, *collection.get(*dependencies).tables)

          # add the cte to the collection
          collection.add(key, Expression::Cte.new(table, cte, dependencies))
        end
        collection
      end

      # Return the CTEs for the coverage series. Return value is passed to the
      # .with method of an Arel::SelectManager
      def coverage_series_ctes(coverage_cte_collection)
        coverage_cte_collection.slice_with_dependencies(:final_coverage).ctes
      end

      # Return the expression used for a projection in a report query.
      # @param coverage_cte_collection [Report::Expression::Collection] The
      #   collection of CTEs containing the required Arel::Table
      # @param name [String] The name to use for the output field
      # @todo should support directly passing the required table
      def coverage_series_arel(coverage_cte_collection, name)
        coverage_json(*coverage_cte_collection.get(:final_coverage).tables, name)
      end

      # Given a start time, end time, and a scaling factor, calculate the gap
      # size interval to use when calculating a coverage series. The scaling
      # factor defines the maximum units of time that can be emitted in a series
      # of coverage values.
      #
      # @param time_series_options [Hash] The options to use for the query
      # @param time_series_options[:start_time] [String, DateTime] series start
      # @param time_series_options[:end_time] [String, DateTime] series end
      # @param time_series_options[:scaling_factor] [Integer]
      # @return [Report.Query] containing the cte and table.
      def calculate_gap_size(time_series_options)
        start_time = Arel.quoted(time_series_options[:start_time]).cast(:datetime)
        end_time = Arel.quoted(time_series_options[:end_time]).cast(:datetime)
        scaling_factor = time_series_options[:scaling_factor] || 1920

        range = TimeSeries.time_range_expression(start_time, end_time)
        report_range = Arel::Nodes::TableAlias.new(
          manager.project(range.as('range')), 'report_range'
        )

        upper_epoch = TimeSeries.upper(report_range[:range]).extract('epoch')
        lower_epoch = report_range[:range].lower.extract('epoch')

        seconds = upper_epoch - lower_epoch
        scaled_seconds = seconds / scaling_factor
        report_range_interval = arel_seconds_to_interval(scaled_seconds)

        table = Arel::Table.new(:gap_size)
        cte = Arel::Nodes::As.new(
          table,
          manager
          .project(report_range_interval.as('gap_size'))
          .from(report_range)
        )

        [table, cte]
      end

      # Given a start and end time, calculate the gap size interval to use when
      # calculating a coverage series, based on a provided scaling factor.
      # @return [Arel::Table, Arel::Nodes::As] the cte and table.
      def x_calculate_gap_size(start_time, end_time, scaling_factor)
        start_time = Arel.quoted(start_time).cast(:datetime)
        end_time = Arel.quoted(end_time).cast(:datetime)

        range = TimeSeries.time_range_expression(start_time, end_time)
        report_range = Arel::Nodes::TableAlias.new(
          manager.project(range.as('range')), 'report_range'
        )

        upper_epoch = TimeSeries.upper(report_range[:range]).extract('epoch')
        lower_epoch = report_range[:range].lower.extract('epoch')

        seconds = upper_epoch - lower_epoch
        scaled_seconds = seconds / scaling_factor
        report_range_interval = arel_seconds_to_interval(scaled_seconds)

        table = Arel::Table.new(:gap_size)
        cte = Arel::Nodes::As.new(
          table,
          manager
          .project(report_range_interval.as('gap_size'))
          .from(report_range)
        )

        [table, cte]
      end

      # Creates a PostgreSQL interval from seconds
      def arel_seconds_to_interval(seconds)
        Arel::Nodes::NamedFunction.new(
          'make_interval',
          [Arel.sql('secs => ?', seconds)]
        )
      end

      # returns an expression that projects the absolute end date of an audio
      # event as a derived columnn
      def arel_recorded_end_date
        # AudioRecording.arel_table[:recorded_date].+(Arel::Nodes.build_quoted('3600 seconds'))
        Arel::Nodes::SqlLiteral.new('audio_recordings.recorded_date + CAST(audio_recordings.duration_seconds || \' seconds\' as interval)')
      end

      # Return a cte with fields for start, end, and previous end time
      # Rows are sorted based on the lower_field (start time)
      # previous end time is a derived column (null for the first row)
      # representing the end_time of the previous row
      # @param options [Hash] The options to use for the query
      def sort_with_lag(options)
        source = options[:source]

        time_lower = options.dig(:fields, :lower_field)
        time_upper = options.dig(:fields, :upper_field)

        window = Arel::Nodes::Window.new.order(time_lower)
        lag = Arel::Nodes::NamedFunction.new('LAG', [time_upper]).over(window)

        # start by getting the sorted_recordings CTE
        table = Arel::Table.new(:sorted_recordings)
        cte = Arel::Nodes::As.new(
          table,
          manager.project(
            time_lower.as('start_time'),
            time_upper.as('end_time'),
            lag.as('prev_end')
          ).from(source)
        )
        [table, cte]
      end

      # categorise each row into a group, starting from 0
      # where group id is incremented by 1 when the start time
      # is greater than the previous end time + gap size
      #
      # Note: the _gap_size parameter is currently unused due to the inline sql,
      # but the signature is preserved, allowing the dependency to be recorded
      # during the pipeline. Important so that the cte can be later resolved.
      def grouped(sorted_with_lag, _gap_size)
        # building the case statement in native arel caused postgres transaction
        # fails. narrowed it down to the field qualifiers that are added e.g.
        # 'WHEN sorted_recordings.start_time > sorted_recordings.prev_end' fails
        # but 'WHEN start_time > prev_end works
        group_id = Arel.sql(
          <<~SQL.squish
            SUM(CASE WHEN start_time > prev_end + gap.gap_size THEN 1 ELSE 0 END)
            OVER (ORDER BY start_time) AS group_id
          SQL
        )

        cross_join = Arel::Nodes::SqlLiteral.new('CROSS JOIN gap_size as gap')

        table = Arel::Table.new(:grouped)
        cte = Arel::Nodes::As.new(
          table,
          manager.project(Arel.star, group_id).from(sorted_with_lag).join(cross_join)
        )
        [table, cte]
      end

      # get the start and end times for each group
      def coverage_intervals(grouped)
        # this is the coverage_intervals CTE
        table = Arel::Table.new(:coverage_intervals)

        cte = Arel::Nodes::As.new(
          table,
          grouped.project(
            grouped[:group_id],
            grouped[:start_time].minimum.as('coverage_start'),
            grouped[:end_time].maximum.as('coverage_end')
          ).group(grouped[:group_id])
        )
        [table, cte]
      end

      # sweep line approach starts here and follows in the next ctes
      # collapse the start and end times into a field with an identifier
      def coverage_events(grouped)
        select = Arel::Nodes::Grouping.new(
            grouped.project(
              grouped[:group_id],
              grouped[:start_time].as('event_time'),
              Arel::Nodes.build_quoted(1).as('delta')
            ).union_all(
            grouped.project(
              grouped[:group_id],
              grouped[:end_time].as('event_time'),
              Arel::Nodes.build_quoted(-1).as('delta')
            )
          )
          )
        table = Arel::Table.new(:coverage_events)
        cte = Arel::Nodes::As.new(
          table,
          select
        )
        [table, cte]
      end

      # calculate the running sum of the delta values for each group
      # when the delta is positive there is an event active within the group
      # when the delta is 0 it indicates a gap in the group
      def coverage_events_sorted_sum(coverage_events)
        table = Arel::Table.new(:sorted_events)
        cte = Arel::Nodes::As.new(
          table,
          coverage_events.project(
            coverage_events[:group_id],
            coverage_events[:event_time],
            Arel::Nodes::NamedFunction.new('SUM', [coverage_events[:delta]]).over(
              Arel::Nodes::Window.new
                .partition(coverage_events[:group_id])
                .order(coverage_events[:event_time])
                .order(coverage_events[:delta].desc)
            ).as('running_sum')
          )
        )
        [table, cte]
      end

      # TODO: confusing names and similar method names
      # add the next_event_time field that will be used to calculate the
      # duration of events and groups
      def covered_intervals(coverage_events_sorted_sum)
        table = Arel::Table.new(:covered_intervals)
        cte = Arel::Nodes::As.new(
          table,
          coverage_events_sorted_sum.project(
            coverage_events_sorted_sum[:group_id],
            coverage_events_sorted_sum[:event_time],
            Arel::Nodes::NamedFunction.new('LEAD', [coverage_events_sorted_sum[:event_time]]).over(
              Arel::Nodes::Window.new
                .partition(coverage_events_sorted_sum[:group_id])
                .order(coverage_events_sorted_sum[:event_time])
            ).as('next_event_time'),
            coverage_events_sorted_sum[:running_sum]
          )
        )
        [table, cte]
      end

      # within each group, get the sum of the durations of all the events an
      # event is either a start or end time, and next_end_time does not
      # necessarily correspond to a separate row in the context of the original
      # data e.g. event time 0 and next_event_time 10 could represent a start
      # and end time of a single recording, or two separate recordings.
      def covered_durations(covered_intervals)
        next_event_time = Arel::Nodes::SqlLiteral.new('next_event_time')
        event_time = Arel::Nodes::SqlLiteral.new('event_time')

        covered_seconds = Arel::Nodes::Subtraction.new(next_event_time, event_time).extract('epoch').sum

        table = Arel::Table.new(:covered_durations)
        cte = Arel::Nodes::As.new(
          table,
          covered_intervals.project(
            covered_intervals[:group_id],
            covered_seconds.as('total_covered_seconds')
          ).where(
            covered_intervals[:running_sum].gt(0)
              .and(covered_intervals[:next_event_time].not_eq(nil))
          ).group(covered_intervals[:group_id])
        )
        [table, cte]
      end

      def final_coverage(coverage_intervals, covered_durations)
        table = Arel::Table.new(:final_coverage)
        cte = Arel::Nodes::As.new(
          table,
          coverage_intervals.project(
            coverage_intervals[:group_id],
            coverage_intervals[:coverage_start],
            coverage_intervals[:coverage_end],
            covered_durations[:total_covered_seconds], # not used atm
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
          ).join(covered_durations, Arel::Nodes::OuterJoin).on(coverage_intervals[:group_id].eq(covered_durations[:group_id]))
          .group(coverage_intervals[:group_id], coverage_intervals[:coverage_start], coverage_intervals[:coverage_end], covered_durations[:total_covered_seconds])
          .order(coverage_intervals[:group_id])
        )
        [table, cte]
      end

      # Query to project an aggregated json column of coverage results.
      # To execute the query, the final_coverage CTE and all dependency CTEs
      # must be included in the `.with` clause of an Arel::SelectManager.
      #
      # @param [Arel::Table] final_coverage table, used as `.from` for query
      # @param [String] name alias to use for the output field
      #
      # @return [Arel::SelectManager] Arel::SelectManager object with the json
      def coverage_json(final_coverage, name)
        range = Report::TimeSeries.time_range_expression(final_coverage[:coverage_start],
          final_coverage[:coverage_end])
        json = Arel.json({ 'range' => range, 'density' => final_coverage[:density].round(3) })
        Arel::SelectManager.new.project(json.json_agg.as(name.to_s)).from(final_coverage)
      end
    end
  end
end
