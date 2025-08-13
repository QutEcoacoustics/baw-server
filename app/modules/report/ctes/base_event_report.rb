# frozen_string_literal: true

module Report
  module Ctes
    # Base class for event reports that use time series data.

    # @see Report::Ctes::BucketAllocate
    # @see Report::Ctes::BaseVerification
    # @see Report::Ctes::SortWithLag
    # @see Report::Ctes::EventComposition
    class BaseEventReport < Report::Cte::Node
      include Cte::Dsl

      table_name :base_table

      select do
        AudioEvent
          .joins(:audio_recording, :taggings)
          .left_joins(:provenance)
          .select({ id: :audio_event_id })
          .select(fields)
          .select_start_absolute
          .select(AudioRecording.arel_recorded_end_date.as('end_date'))
          .arel
          .project(
            provenance[:score_minimum].as('provenance_score_minimum'),
            provenance[:score_maximum].as('provenance_score_maximum'),
            analysis_jobs_items[:result].as('result')
          )
          .join(analysis_jobs_items, Arel::Nodes::OuterJoin)
          .on(analysis_jobs_items[:audio_recording_id].eq(audio_events[:audio_recording_id]))
      end

      def self.fields
        [:tag_id, :score, :provenance_id, :recorded_date, :duration_seconds]
      end

      def self.audio_events = AudioEvent.arel_table
      def self.provenance = Provenance.arel_table
      def self.analysis_jobs_items = AnalysisJobsItem.arel_table
    end
  end
end
