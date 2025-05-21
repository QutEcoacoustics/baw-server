# frozen_string_literal: true

module Report
  module TimeSeries
    # Module for generating coverage series CTEs. Temporal coverage is reported
    # as a series of coverage objects, with a range value for the coveral
    # interval. An interval is a grouping of one or more temporal events. Events
    # can be non-overlapping - close proximity events are grouped according to
    # the scaling factor. The density or fractional coverage of each interval is
    # also reported.
    module Coverage
      module_function

      include Report::ArelHelpers
      extend Report::ArelHelpers

      # @param source [Arel::Table] The source table containing fields to use
      # @param fields [Hash]
      #   :lower_field [Arel::Attributes::Attribute, Arel::Nodes::Node]
      #   :upper_field [Arel::Attributes::Attribute, Arel::Nodes::Node]
      # @param project_field_as [String] projected JSON aggregation field name
      def coverage_options(source:, fields:, **options)
        {
          source: source,
          fields: fields,
          project_field_as: 'coverage',
          analysis_result: false,
          add_source_to_collection: false
        }.merge(options)
      end

      def pipeline_steps
        {
          grouped: [:sort_with_lag, :gap_size],
          coverage_intervals: [:grouped],
          coverage_events: [:grouped],
          coverage_events_sorted_sum: [:coverage_events],
          covered_intervals: [:coverage_events_sorted_sum],
          covered_durations: [:covered_intervals],
          final_coverage: [:coverage_intervals, :covered_durations]
        }
      end

      def coverage_series(time_series_options, coverage_options, collection = nil)
        # A prefix is used because coverage_series is called twice, once for
        # recordings, and again for analysis results, so unique table names are
        # needed to prevent a postgres error.
        prefix = coverage_options[:project_field_as]
        collection ||= Report::Expression::Collection.new

        calculate_gap_size(time_series_options, options = coverage_options).tap do |table, cte|
          collection.add(:"#{prefix}_gap_size", Expression::Cte.new(table, cte))
        end

        sort_with_lag(coverage_options).tap do |table, cte|
          source_table_name_symbol = (if coverage_options[:add_source_to_collection]
                                        [coverage_options[:source].name.to_sym]
                                      end)

          collection.add(:"#{prefix}_sort_with_lag", Expression::Cte.new(
            table, cte, source_table_name_symbol
          ))
        end

        cte_structure.each do |method_name, dependency_keys|
          prefixed_cte_name = :"#{prefix}_#{method_name}"
          dependency_keys_prefixed = dependency_keys.map { |key| :"#{prefix}_#{key}" }
          dependency_tables = collection.get(dependency_keys_prefixed).tables

          begin
            table, cte = send(method_name, *dependency_tables, options = coverage_options)
          rescue NoMethodError => e
            raise NoMethodError, "Method #{method_name} not found. Error: #{e.message}"
          rescue ArgumentError => e
            raise ArgumentError,
              "Error building cte for key: #{prefixed_cte_name}. Method: #{method_name}. Dependencies: #{dependency_keys_prefixed.inspect}. Received: #{dependency_tables.map(&:name)}. Error: #{e.message}"
          rescue StandardError => e
            raise StandardError, "Error building cte for key: #{prefixed_cte_name}; #{e.message}"
          end

          collection.add(prefixed_cte_name, Expression::Cte.new(table, cte, dependency_keys_prefixed))
        end
        collection
      end

      # Return the expression used for a coverage projection in a report query.
      # @param coverage_cte_collection [Report::Expression::Collection] The
      #   collection of CTEs containing the required Arel::Table
      # @param name [String] The name to use for the output field
      def coverage_series_arel(coverage_cte_collection, options = {})
        prefix = options[:project_field_as]
        final_coverage_cte_name = :"#{prefix}_final_coverage"
        coverage_json(*coverage_cte_collection.get(final_coverage_cte_name).tables, options)
      end

      # Return the final CTEs needed for the coverage series projection. Return
      # value is passed to the .with method of an Arel::SelectManager
      def coverage_series_ctes(coverage_cte_collection, options = {})
        prefix = options[:project_field_as]
        final_coverage_cte_name = :"#{prefix}_final_coverage"
        coverage_cte_collection.get_with_dependencies(final_coverage_cte_name).ctes
      end

      # Given a start time, end time, and a scaling factor, calculate the gap
      # size interval to use when calculating a coverage series. The scaling
      # factor defines the maximum units of time that can be emitted in a series
      # of coverage values.
      #
      # @param time_series_options [Hash] from module timeseries
      # @return [[Arel::Table, Arel::Nodes::As]]
      def calculate_gap_size(time_series_options, options = {})
        prefix = options[:project_field_as]
        scaling_factor = time_series_options[:scaling_factor] || 1920

        start_time = Arel.quoted(time_series_options[:start_time]).cast(:datetime)
        end_time = Arel.quoted(time_series_options[:end_time]).cast(:datetime)

        range = TimeSeries.time_range_expression(start_time, end_time)
        report_range = Arel::Nodes::TableAlias.new(
          manager.project(range.as('range')), 'report_range'
        )

        report_range_interval = range_interval(report_range, scaling_factor)
        select = manager.project(report_range_interval.as('gap_size')).from(report_range)

        build_cte('gap_size', prefix, select)
      end

      def range_interval(report_range, scaling_factor)
        upper_epoch = TimeSeries.upper(report_range[:range]).extract('epoch')
        lower_epoch = report_range[:range].lower.extract('epoch')

        seconds = upper_epoch - lower_epoch
        scaled_seconds = seconds / scaling_factor

        Report::TimeSeries::Coverage.arel_seconds_to_interval(scaled_seconds)
      end

      # Creates a PostgreSQL interval from seconds
      def arel_seconds_to_interval(seconds)
        Arel::Nodes::NamedFunction.new(
          'make_interval',
          [Arel.sql('secs => ?', seconds)]
        )
      end

      # Returns an expression that projects the absolute end date of an audio
      # event as a derived columnn
      def arel_recorded_end_date(source)
        Arel::Nodes::SqlLiteral.new("#{source.name}.recorded_date + CAST(#{source.name}.duration_seconds || ' seconds' as interval)")
      end

      def arel_window_partition_result_sort(partition_by, sort_by)
        Arel::Nodes::Window.new.partition(partition_by).order(sort_by)
      end

      def arel_window_partition_sort(sort_by)
        Arel::Nodes::Window.new.order(sort_by)
      end

      def build_window(sort_by:, partition_by: nil)
        window = Arel::Nodes::Window.new
        window = window.partition(partition_by) if partition_by
        window.order(sort_by)
      end

      def build_lag(column, window)
        Arel::Nodes::NamedFunction.new('LAG', [column]).over(window)
      end

      def sort_with_lag_fields(time_lower, time_upper, lag, result: nil)
        fields = [time_lower.as('start_time'), time_upper.as('end_time'), lag.as('prev_end')]
        fields.append(result.as('result')) if result
        fields
      end

      def build_cte(table_name, prefix, select)
        table = Arel::Table.new(:"#{prefix}_#{table_name}")
        cte = Arel::Nodes::As.new(table, select)
        [table, cte]
      end

      # Return a cte with fields for start, end, and previous end time Rows are
      # sorted based on the lower_field (start time) previous end time is a
      # derived column (null for the first row) representing the end_time of the
      # previous row
      # @param options [Hash] The options to use for the query
      def sort_with_lag(options = {})
        source = options[:source]
        prefix = options[:project_field_as]
        analysis_result = options[:analysis_result]
        time_lower = options.dig(:fields, :lower_field)
        time_upper = options.dig(:fields, :upper_field)

        window = build_window(
          partition_by: analysis_result ? source[:result] : nil,
          sort_by: time_lower
        )

        lag = build_lag(time_upper, window)
        fields = sort_with_lag_fields(time_lower, time_upper, lag, result: analysis_result ? source[:result] : nil)
        select = Arel::SelectManager.new.project(fields).from(source)
        build_cte('sort_with_lag', prefix, select)
      end

      def arel_group_id_case_statement
        # building the case statement in native arel was causing postgres
        # transaction fails. narrowed it down to the field qualifiers that are
        # added e.g. 'WHEN sorted_recordings.start_time >
        # sorted_recordings.prev_end' fails but 'WHEN start_time > prev_end
        # works. unsure how to fix this in arel
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

      # categorise each row into a group, starting from 0
      # where group id is incremented by 1 when the start time
      # is greater than the previous end time + gap size
      #
      # Note: the _gap_size parameter is currently unused due to the inline sql,
      # but the signature is preserved, allowing the dependency to be recorded
      # during the pipeline. Important so that the cte can be later resolved.
      # temporary hack.
      # Added options hash
      # gap_size_table is now the Arel::Table for the prefixed gap_size
      def grouped(sorted_with_lag, gap_size_table, options = {})
        prefix = options[:project_field_as]
        # Use the actual name of the gap_size table passed in, which is already prefixed.
        cross_join = Arel::Nodes::SqlLiteral.new("CROSS JOIN #{gap_size_table.name} as gap")

        group_id_sql = if options[:analysis_result]
                         arel_group_id_case_statement_by_result
                       else
                         arel_group_id_case_statement
                       end

        table = Arel::Table.new(:"#{prefix}_grouped") # Prefixed table name
        cte = Arel::Nodes::As.new(
          table,
          manager.project(Arel.star, group_id_sql).from(sorted_with_lag).join(cross_join)
        )
        [table, cte]
      end

      # get the start and end times for each group
      # Added options hash
      def coverage_intervals(grouped, options = {})
        prefix = options[:project_field_as]
        table = Arel::Table.new(:"#{prefix}_coverage_intervals") # Prefixed table name

        fields = [
          grouped[:group_id],
          grouped[:start_time].minimum.as('coverage_start'),
          grouped[:end_time].maximum.as('coverage_end')
        ]

        fields << grouped[:result].as('result') if options[:analysis_result]

        group_by_fields = [grouped[:group_id]]
        group_by_fields.unshift(grouped[:result]) if options[:analysis_result] # Prepend for correct grouping order

        cte = Arel::Nodes::As.new(
          table,
          grouped.project(
            fields
          ).group(*group_by_fields) # Use splat operator for group_by
        )
        [table, cte]
      end

      # sweep line approach starts here and follows in the next ctes
      # collapse the start and end times into a field with an identifier
      # Added options hash
      def coverage_events(grouped, options = {})
        prefix = options[:project_field_as]
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

        # Ensure the correct table is used for projection if `grouped` is already a CTE reference
        source_table_for_projection = grouped.is_a?(Arel::Table) ? grouped : Arel::Table.new(grouped.name)

        select = Arel::Nodes::Grouping.new(
            source_table_for_projection.project(top).union_all(source_table_for_projection.project(bottom))
          )

        table = Arel::Table.new(:"#{prefix}_coverage_events") # Prefixed table name
        cte = Arel::Nodes::As.new(
          table,
          select
        )
        [table, cte]
      end

      # calculate the running sum of the delta values for each group
      # when the delta is positive there is an event active within the group
      # when the delta is 0 it indicates a gap in the group
      # Added options hash
      def coverage_events_sorted_sum(coverage_events, options = {})
        prefix = options[:project_field_as]
        window_partitions = [coverage_events[:group_id]]
        window_partitions.unshift(coverage_events[:result]) if options[:analysis_result]

        window = Arel::Nodes::Window.new
          .partition(*window_partitions)
          .order(coverage_events[:event_time], coverage_events[:delta].desc)

        projection_fields = [
          coverage_events[:group_id],
          coverage_events[:event_time],
          Arel::Nodes::NamedFunction.new('SUM', [coverage_events[:delta]]).over(
            window
          ).as('running_sum')
        ]

        projection_fields.unshift(coverage_events[:result]) if options[:analysis_result]

        select = coverage_events.project(*projection_fields)

        table = Arel::Table.new(:"#{prefix}_coverage_events_sorted_sum") # Prefixed table name
        cte = Arel::Nodes::As.new(table, select)
        [table, cte]
      end

      # TODO: confusing names and similar method names
      # add the next_event_time field that will be used to calculate the
      # duration of events and groups
      # Added options hash
      def covered_intervals(coverage_events_sorted_sum, options = {})
        prefix = options[:project_field_as]

        window_partitions = [coverage_events_sorted_sum[:group_id]]
        window_partitions.unshift(coverage_events_sorted_sum[:result]) if options[:analysis_result]

        window = Arel::Nodes::Window.new
          .partition(*window_partitions)
          .order(coverage_events_sorted_sum[:event_time])

        projection_fields = [
          coverage_events_sorted_sum[:group_id],
          coverage_events_sorted_sum[:event_time],
          Arel::Nodes::NamedFunction.new('LEAD',
            [coverage_events_sorted_sum[:event_time]]).over(window).as('next_event_time'),
          coverage_events_sorted_sum[:running_sum]
        ]
        projection_fields.unshift(coverage_events_sorted_sum[:result]) if options[:analysis_result]

        select = coverage_events_sorted_sum.project(*projection_fields)
        table = Arel::Table.new(:"#{prefix}_covered_intervals") # Prefixed table name

        cte = Arel::Nodes::As.new(table, select)
        [table, cte]
      end

      # within each group, get the sum of the durations of all the events an
      # event is either a start or end time, and next_end_time does not
      # necessarily correspond to a separate row in the context of the original
      # data e.g. event time 0 and next_event_time 10 could represent a start
      # and end time of a single recording, or two separate recordings.
      # Added options hash
      def covered_durations(covered_intervals, options = {})
        prefix = options[:project_field_as]
        next_event_time = Arel::Nodes::SqlLiteral.new('next_event_time')
        event_time = Arel::Nodes::SqlLiteral.new('event_time')

        covered_seconds = Arel::Nodes::Subtraction.new(next_event_time, event_time).extract('epoch').sum

        group_by_fields = [covered_intervals[:group_id]]
        group_by_fields.unshift(covered_intervals[:result]) if options[:analysis_result]

        projection_fields = [
          covered_intervals[:group_id],
          covered_seconds.as('total_covered_seconds')
        ]
        projection_fields.unshift(covered_intervals[:result]) if options[:analysis_result]

        select = covered_intervals.project(*projection_fields).where(
          covered_intervals[:running_sum].gt(0)
            .and(covered_intervals[:next_event_time].not_eq(nil))
        ).group(*group_by_fields)

        table = Arel::Table.new(:"#{prefix}_covered_durations") # Prefixed table name
        cte = Arel::Nodes::As.new(table, select)
        [table, cte]
      end

      # Added options hash
      def final_coverage(coverage_intervals, covered_durations, options = {})
        prefix = options[:project_field_as]

        projection_fields = [
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
        projection_fields.unshift(coverage_intervals[:result]) if options[:analysis_result]

        select = Arel::SelectManager.new # Use a new SelectManager for clarity
          .project(*projection_fields)
          .from(coverage_intervals) # Start with coverage_intervals

        select = if options[:analysis_result]
                   select.join(covered_durations, Arel::Nodes::OuterJoin)
                     .on(coverage_intervals[:result].eq(covered_durations[:result])
                                .and(coverage_intervals[:group_id].eq(covered_durations[:group_id])))
                     .order(coverage_intervals[:result], coverage_intervals[:group_id])
                 else
                   select.join(covered_durations, Arel::Nodes::OuterJoin)
                     .on(coverage_intervals[:group_id].eq(covered_durations[:group_id]))
                     .order(coverage_intervals[:group_id])
                 end

        table = Arel::Table.new(:"#{prefix}_final_coverage") # Prefixed table name
        cte = Arel::Nodes::As.new(table, select)
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
      def coverage_json(final_coverage, options = {})
        range = Report::TimeSeries.time_range_expression(final_coverage[:coverage_start],
          final_coverage[:coverage_end])

        fields = { 'range' => range,
                   'density' => final_coverage[:density].round(3) }
        fields = fields.merge('type' => final_coverage[:result]) if options[:analysis_result]

        json = Arel.json(fields)

        project_field_as = options[:project_field_as] || 'coverage'
        Arel::SelectManager.new.project(json.json_agg.as(project_field_as.to_s)).from(final_coverage)
      end
    end
  end
end
