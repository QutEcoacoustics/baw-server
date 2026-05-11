# frozen_string_literal: true

module Api
  module Reporting
    # Contiguous groups within a threshold are collapsed into islands whose
    # density (actual coverage / total coverage period) is then computed. The gap
    # threshold is calculated as 1/1920th of the total span of all recordings.
    # Calculated within customisable partitions (e.g. by site, or by site and analysis result type).
    #
    # Implements #call(query) for use as a template in execute_report.
    class Coverage
      include CteHelper

      RECORDINGS = Arel::Table.new(:filtered_recordings)
      ISLANDS    = Arel::Table.new(:islands)

      RECORDING_RANGE = 'recording_range'

      # @param partition_columns [Array<Arel::Attributes::Attribute>] columns to partition and group by
      # @param joins [Array<Arel::Nodes::Join>] optional; any joins needed to apply to the base query
      def initialize(partition_columns: [], joins: nil)
        @partition_columns = partition_columns
        @joins = joins
      end

      # @param table [Arel::Table]
      # @return [Array<Arel::Attributes>] Return the partition columns as attributes for the given table
      def partition_columns(table)
        @partition_columns.map { |attribute| table[attribute.name] }
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        ISLANDS
          .project(
            *partition_columns(ISLANDS),
            Arel.tsrange(
              ISLANDS[:recording_range].lower.minimum,
              ISLANDS[:recording_range].upper.maximum
            ).as('coverage'),
            ISLANDS[:gap_threshold]
          )
          .group(
            ISLANDS[:island_id],
            ISLANDS[:gap_threshold],
            *partition_columns(ISLANDS)
          )
          .order(*partition_columns(ISLANDS), ISLANDS[:recording_range].lower.minimum)
          .with(*ctes(query:))
      end

      # Arel expression for a density calculation of coverage, to be used as a projection
      def self.coverage_density
        coverage_span = Arel::Nodes::Subtraction.new(
          ISLANDS[:recording_range].upper.maximum,
          ISLANDS[:recording_range].lower.minimum
        ).extract('epoch')

        # ! TODO: Division when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Division.new(
          Arel.tsmultirange_total_seconds(ISLANDS[:recording_range].range_agg),
          Arel::Nodes::NamedFunction.new('NULLIF', [coverage_span, Arel.sql('0')])
        )
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
        # ! TODO: Division when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        RECORDINGS.project(Arel.seconds(Arel::Nodes::Division.new(span.extract('epoch'), 1920)).as('val'))
      end

      def gap_threshold_table_alias = Arel::Nodes::TableAlias.new(threshold_cte, 'gap_threshold')

      def islands_cte
        window = Arel::Nodes::Window.new
          .partition(*partition_columns(RECORDINGS))
          .order(RECORDINGS[:recording_range].lower)

        # Using a custom PostgreSQL aggregate function to assign numbers to distinct islands (groups separated by > gap_threshold)
        # (see AddContiguousRangeNumberFunction migration)
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
