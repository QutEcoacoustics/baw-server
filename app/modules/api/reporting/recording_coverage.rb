# frozen_string_literal: true

module Api
  module Reporting
    # Report template with the required CTEs and joins to produce a report of
    # recording coverage. Coverage is calculated as the total period covered by
    # contiguous group of recordings separated by gaps smaller than a calculated
    # threshold. Density is reported as the ratio of actual time covered to the
    # total covered period for the group.
    #
    # Implements #call(query) for use as a template in execute_report.

    class RecordingCoverage
      include Api::Reporting::CteHelper

      RECORDINGS = Arel::Table.new(:filtered_recordings)

      def call(query)
        debugger
        query.arel

        ar = AudioRecording
        recording_range_col = :recording_range

        # ---- Base query ----
        recording_range_arel = Arel.tsrange(ar.arel_table[:recorded_date], ar.arel_recorded_end_date)
        lag_recording_range = Arel::Nodes::NamedFunction.new('lag', [recording_range_arel.dup])
        window = Arel::Nodes::Window.new.order(ar.arel_table[:recorded_date])
        previous_recording_range = lag_recording_range.over(window)

        recordings_query = AudioRecording.arel_table.project(
          ar.arel_table[:id],
          ar.arel_table[:recorded_date],
          ar.arel_table[:recorded_utc_offset],
          recording_range_arel.as(recording_range_col.to_s),
          previous_recording_range.as('previous_recording_range')
        )

        recordings_cte = cte(RECORDINGS, recordings_query)

        # --- define_coverage_periods
        gap_threshold_span = Arel::Nodes::Subtraction.new(
          RECORDINGS[recording_range_col].upper.maximum,
          RECORDINGS[recording_range_col].lower.minimum
        )

        gap_threshold_seconds = Arel::Nodes::Division.new(gap_threshold_span.extract('epoch'), 1920)
        gap_threshold_query = RECORDINGS.project(
          Arel.seconds(gap_threshold_seconds).as('seconds')
        )
        gap_threshold_table = Arel::Table.new(:gap_threshold)
        gap_threshold_table_alias = Arel::Nodes::TableAlias.new(gap_threshold_query, 'gap_threshold')
        # gap_threshold_table_alias = Arel::Nodes::TableAlias.new(gap_threshold_query, Arel.sql('gap_threshold (seconds)'))

        define_coverage_periods = Arel::Table.new(:define_coverage_periods)

        previous_range_upper_with_gap = Arel::Nodes::InfixOperation.new(
          '+',
          RECORDINGS[:previous_recording_range].upper,
          gap_threshold_table_alias[:seconds]
        )

        previous_range_with_gap = Arel.tsrange(
          RECORDINGS[:previous_recording_range].lower,
          previous_range_upper_with_gap
        )

        starts_new_period = Arel::Nodes::InfixOperation.new(
          '>>',
          RECORDINGS[recording_range_col],
          previous_range_with_gap
        )

        period_id_window = Arel::Nodes::Window.new.order(RECORDINGS[recording_range_col].lower)

        period_id = Arel::Nodes::NamedFunction
          .new('SUM', [starts_new_period.cast('int')])
          .over(period_id_window)
          .as('period_id')

        define_coverage_periods_query = RECORDINGS
          .project(
            RECORDINGS[recording_range_col],
            period_id,
            gap_threshold_table_alias[:seconds].as('gap_threshold')
          )
          .join(Arel::Nodes::Lateral.new(gap_threshold_table_alias))
          .on(Arel.sql('true'))

        define_coverage_periods_cte = cte(define_coverage_periods, define_coverage_periods_query)

        # --- recording_range_boundaries
        recording_range_boundaries = Arel::Table.new(:recording_range_boundaries)
        recording_start_boundaries_query = define_coverage_periods
          .project(
            define_coverage_periods[:period_id],
            define_coverage_periods[recording_range_col].lower.as('boundary_timestamp'),
            Arel.sql('1').as('score')
          )

        recording_end_boundaries_query = define_coverage_periods
          .project(
            define_coverage_periods[:period_id],
            define_coverage_periods[recording_range_col].upper.as('boundary_timestamp'),
            Arel.sql('-1').as('score')
          )

        recording_range_boundaries_query = Arel::Nodes::UnionAll.new(
          recording_start_boundaries_query.ast,
          recording_end_boundaries_query.ast
        )

        recording_range_boundaries_cte = cte(recording_range_boundaries, recording_range_boundaries_query)

        # ---sweep_range_boundaries
        sweep_range_boundaries = Arel::Table.new(:sweep_range_boundaries)
        next_boundary_window = Arel::Nodes::Window
          .new
          .partition(recording_range_boundaries[:period_id])
          .order(recording_range_boundaries[:boundary_timestamp])

        next_boundary_timestamp = Arel::Nodes::NamedFunction
          .new('LEAD', [recording_range_boundaries[:boundary_timestamp]])
          .over(next_boundary_window)

        active_recordings_window = Arel::Nodes::Window
          .new
          .partition(recording_range_boundaries[:period_id])
          .order(recording_range_boundaries[:boundary_timestamp], recording_range_boundaries[:score].desc)

        active_recordings_count = recording_range_boundaries[:score]
          .sum
          .over(active_recordings_window)

        sweep_range_boundaries_query = recording_range_boundaries
          .project(
            recording_range_boundaries[:period_id],
            recording_range_boundaries[:boundary_timestamp],
            next_boundary_timestamp.as('next_boundary_timestamp'),
            active_recordings_count.as('active_recordings_count')
          )

        sweep_range_boundaries_cte = cte(sweep_range_boundaries, sweep_range_boundaries_query)

        # --- actual_coverage
        actual_coverage = Arel::Table.new(:actual_coverage)

        covered_duration = Arel::Nodes::Subtraction.new(
          sweep_range_boundaries[:next_boundary_timestamp],
          sweep_range_boundaries[:boundary_timestamp]
        ).extract('epoch')
        actual_coverage_query = sweep_range_boundaries
          .project(
            sweep_range_boundaries[:period_id],
            covered_duration.sum.as('total_covered_seconds')
          )
          .where(
            sweep_range_boundaries[:active_recordings_count]
              .gt(0)
              .and(sweep_range_boundaries[:next_boundary_timestamp].is_not_null)
          )
          .group(sweep_range_boundaries[:period_id])

        actual_coverage_cte = cte(actual_coverage, actual_coverage_query)

        # --- coverage_with_density
        coverage_with_density = Arel::Table.new(:coverage_with_density)

        coverage_lower = define_coverage_periods[:recording_range].lower.minimum
        coverage_upper = define_coverage_periods[:recording_range].upper.maximum

        coverage_duration = Arel::Nodes::Subtraction.new(coverage_upper, coverage_lower).extract('epoch')

        density = Arel::Nodes::Division.new(
          actual_coverage[:total_covered_seconds],
          coverage_duration
        )

        coverage_with_density_query = define_coverage_periods
          .project(
            define_coverage_periods[:period_id],
            define_coverage_periods[:gap_threshold],
            Arel.tsrange(coverage_lower, coverage_upper).as('coverage'),
            density.as('density')
          )
          .join(actual_coverage, Arel::Nodes::OuterJoin)
          .on(define_coverage_periods[:period_id].eq(actual_coverage[:period_id]))
          .group(
            define_coverage_periods[:period_id],
            define_coverage_periods[:gap_threshold],
            actual_coverage[:total_covered_seconds]
          )

        coverage_with_density_cte = cte(coverage_with_density, coverage_with_density_query)

        # Interactive testing

        ap AudioRecording.exec_query_casted(
          coverage_with_density
          .project(
            coverage_with_density[:gap_threshold],
            coverage_with_density[:coverage].array_agg.order(coverage_with_density[:coverage].lower).as('coverage')
          )
            .with(
              recordings_cte,
              define_coverage_periods_cte,
              recording_range_boundaries_cte,
              sweep_range_boundaries_cte,
              actual_coverage_cte,
              coverage_with_density_cte
            )
            # .order(coverage_with_density[:coverage].lower)
            .group(coverage_with_density[:gap_threshold])
        ).to_a

        # no-op
      end

      def recordings_cte
        recordings_cte = query
          .except(:select, :order, :limit, :offset)
          .reselect(
            ar.arel_table[:id],
            ar.arel_table[:recorded_date],
            ar.arel_table[:recorded_utc_offset],
            ar.arel_recorded_end_date.as('recorded_end_date'),
            ar.arel_timezone.as('recorded_date_timezone')
          ).arel

        recordings_cte_node = cte(RECORDINGS, recordings_cte)
      end
    end
  end
end
