# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # categorise each row into a group, starting from 0.
      # group id is incremented by 1 when the start time is greater than the
      # previous end time + gap size
      class CategoriseIntervals < Report::Cte::NodeTemplate
        table_name :categorise_intervals

        depdendencies sort_temporal_events: Report::Ctes::Coverage::SortTemporalEvents,
          gap_size_table: Report::Ctes::Coverage::IntervalGapSize

        select do
          cross_join = Arel::Nodes::SqlLiteral.new("CROSS JOIN #{gap_size_table.name} as gap")

          group_id_sql = if options[:analysis_result]
                           arel_group_id_case_statement_by_result
                         else
                           arel_group_id_case_statement
                         end

          sort_temporal_events.project(Arel.star, group_id_sql).join(cross_join)
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
    end
  end
end
