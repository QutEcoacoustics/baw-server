# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Defines a CTE that groups temporal events into continuous intervals.
      #
      # It categorises each row from the `sort_temporal_events` CTE into a group,
      # starting from 0. A new group is started when the time between an event's
      # start and the previous event's end is larger than the calculated `gap_size`.
      # This is used to identify continuous blocks of audio coverage.
      #
      # If the `analysis_result` option is true, grouping is done separately for
      # each distinct value of the `result` column (see {AnalysisJobsItem}),
      # allowing intervals to be calculated per analysis result type.
      #
      # == query output
      #
      #  inherits columns from `sort_temporal_events`:
      #    start_time (timestamp without time zone)  -- the start time of the event
      #    end_time   (timestamp without time zone)  -- the end time of the event
      #    prev_end   (timestamp without time zone)  -- the end time of the previous event in the series
      #    result     (analysis_jobs_item_result)    -- (optional) the analysis result type
      #
      #  inherits columns from `interval_gap_size`:
      #    gap_size   (interval)  -- the minimum gap size to consider events part of the same interval
      #
      #  emits column:
      #    group_id   (bigint)   -- sequential group index, 0-based.
      class CategoriseIntervals < Cte::NodeTemplate
        table_name :categorise_intervals

        dependencies sort_temporal_events: Report::Ctes::Coverage::SortTemporalEvents,
          interval_gap_size: Report::Ctes::Coverage::IntervalGapSize

        select do
          cross_join = Arel::Nodes::SqlLiteral.new("CROSS JOIN #{interval_gap_size.name} as gap")

          group_id_sql = if options[:analysis_result]
                           arel_group_id_case_statement_by_result
                         else
                           arel_group_id_case_statement
                         end

          sort_temporal_events.project(Arel.star, group_id_sql).join(cross_join)
        end

        def self.arel_group_id_case_statement
          # ? building the case statement in arel was causing postgres transaction failures
          # using arel, the generated SQL causing issues was 'WHEN sorted_recordings.start_time > sorted_recordings.prev_end'
          # But the below SQL, without the table specifier, works
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
    end
  end
end
