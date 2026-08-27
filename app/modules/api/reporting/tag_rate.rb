# frozen_string_literal: true

module Api
  module Reporting
    class TagRate
      include CteHelper

      RECORDINGS = Arel::Table.new(:filtered_recordings)
      RECORDING_RANGE = 'recording_range'

      def initialize(options = {})
        @bucketer = Bucketer.new(options)
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        AudioRecording.exec_query_casted(
          RECORDINGS.project(Arel.star)
          .with(*ctes(query:))
        )
      end

      def ctes(query:)
        [
          cte(RECORDINGS, recordings_cte(query)),
          *@bucketer.bucket_ctes(source_table: RECORDINGS, source_columns: [
            RECORDINGS[RECORDING_RANGE].lower.minimum,
            RECORDINGS[RECORDING_RANGE].upper.maximum
          ])
        ]
      end

      def recordings_cte(query)
        query
          .except(:select, :order, :limit, :offset)
          .reselect(
            recording_range_arel.as(RECORDING_RANGE),
            AudioRecording.arel_table[:id].as('recording_id')
          ).arel
      end

      # TODO: move to audio recording model?
      def recording_range_arel
        Arel.tsrange(AudioRecording.arel_table[:recorded_date], AudioRecording.arel_recorded_end_date)
      end
    end
  end
end
