# frozen_string_literal: true

module Api
  module Reporting
    # Contiguous groups within a threshold are collapsed into islands whose
    # density (actual coverage / total period) is then computed. The gap
    # threshold is calculated as 1/1920th of the total span of all recordings.
    #
    # Implements #call(query) for use as a template in execute_report.
    class Coverage
      include CteHelper

      RECORDINGS      = Arel::Table.new(:filtered_recordings)
      ISLANDS         = Arel::Table.new(:islands)

      RECORDING_RANGE = 'recording_range'

      def initialize(partition_columns:, joins: nil)
        @partition_columns = partition_columns
        @joins = joins
      end

      # Carry forward any partition column projections at each stage
      def partition_columns(table)
        @partition_columns.map { |attribute| table[attribute.name] }
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        coverage_lower = ISLANDS[:recording_range].lower.minimum
        coverage_upper = ISLANDS[:recording_range].upper.maximum
        coverage_span  = Arel::Nodes::Subtraction.new(coverage_upper, coverage_lower).extract('epoch')

        range_agg     = Arel::Nodes::NamedFunction.new('range_agg', [ISLANDS[:recording_range]])
        total_seconds = Arel::Nodes::NamedFunction.new('tsmultirange_total_seconds', [range_agg])
        density       = Arel::Nodes::Division.new(
          total_seconds,
          Arel::Nodes::NamedFunction.new('NULLIF', [coverage_span, Arel.sql('0')])
        )
        ISLANDS
          .project(
            *partition_columns(ISLANDS),
            Arel.tsrange(coverage_lower, coverage_upper).as('period_range'),
            density.as('density'),
            ISLANDS[:gap_threshold]
          )
          .group(
            ISLANDS[:island_id],
            ISLANDS[:gap_threshold],
            *partition_columns(ISLANDS)
          )
          .with(*ctes(query:))
      end

      def coverage_density
        # noop
      end

      private

      def ctes(query:)
        [
          cte(RECORDINGS, recordings_cte(query)),
          cte(ISLANDS, islands_cte)
        ]
      end

      def recordings_cte(query)
        query = query.joins(@joins) if @joins
        query
          .except(:select, :order, :limit, :offset)
          .reselect(
            recording_range_arel.as('recording_range'),
            *@partition_columns
          ).arel
      end

      def recording_range_arel
        Arel.tsrange(AudioRecording.arel_table[:recorded_date], AudioRecording.arel_recorded_end_date)
      end

      def threshold_cte
        span = Arel::Nodes::Subtraction.new(
          RECORDINGS[:recording_range].upper.maximum,
          RECORDINGS[:recording_range].lower.minimum
        )
        seconds = Arel::Nodes::Division.new(span.extract('epoch'), 1920)

        RECORDINGS.project(Arel.seconds(seconds).as('val'))
      end

      def gap_threshold_table_alias = Arel::Nodes::TableAlias.new(threshold_cte, 'gap_threshold')

      def islands_cte
        window = Arel::Nodes::Window.new
          .partition(*partition_columns(RECORDINGS))
          .order(RECORDINGS[:recording_range].lower)

        island_id = Arel::Nodes::NamedFunction
          .new('contiguous_range_number', [RECORDINGS[:recording_range], gap_threshold_table_alias[:val]])
          .over(window)

        RECORDINGS
          .project(
            RECORDINGS[:recording_range],
            island_id.as('island_id'),
            *partition_columns(RECORDINGS),
            gap_threshold_table_alias[:val].as('gap_threshold')
          )
          .join(Arel::Nodes::Lateral.new(gap_threshold_table_alias))
          .on(Arel.sql('true'))
      end
    end
  end
end
