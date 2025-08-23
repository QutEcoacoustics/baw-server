# frozen_string_literal: true

module Report
  module Ctes
    # Base class for event reports that use time series data.

    # Immediate decendants:
    #  @see Report::Ctes::BucketAllocate
    #  @see Report::Ctes::BaseVerification
    #  @see Report::Ctes::SortWithLag
    #  @see Report::Ctes::EventComposition
    #
    # AudioEvent report root node:
    # @see Report::AudioEvents
    class BaseEventReport < Report::Cte::Node
      include Cte::Dsl

      table_name :base_table

      default_options base_scope: -> { default_relation_scope }

      select do
        selection = joins.call(base_scope)
        selection.project(attributes)
      end

      # The reason for joins here, instead of #joins method, is that in the report controler,
      # a scope is returned to base the requery on, which includes audio_recording and site sites.
      # Otherwise, they are projected twice, causing ambiguous reference errors.
      def self.default_relation_scope
        query = AudioEvent.joins(audio_recording: [:site])
        query.select(:audio_recording_id, :provenance_id).arel
      end

      def self.base_scope
        scope = options[:base_scope]
        scope = scope.call if scope.is_a?(Proc)

        # dup, or else successive calls will append to the same base_scope
        scope.dup if scope.is_a?(Arel::SelectManager)
      end

      def self.joins
        lambda { |query|
          query
            .join(analysis_jobs_items, Arel::Nodes::OuterJoin).on(analysis_jobs_items[:audio_recording_id].eq(audio_events[:audio_recording_id]))
            .join(provenance, Arel::Nodes::OuterJoin).on(provenance[:id].eq(audio_events[:provenance_id]))
            .join(regions, Arel::Nodes::OuterJoin).on(regions[:id].eq(sites[:region_id]))
            .join(taggings).on(audio_events[:id].eq(taggings[:audio_event_id]))
            .join(tags).on(taggings[:tag_id].eq(tags[:id]))
          query
        }
      end

      # @return [Array<Arel::Attributes>] the attributes to select
      def self.attributes
        [
          Arel.sql(AudioEvent.arel_start_absolute),
          Arel.sql(audio_recording_end_date),
          audio_events[:id].as('audio_event_id'),
          audio_events[:score].as('score'),
          regions[:id].as('region_id'),
          sites[:id].as('site_id'),
          taggings[:id].as('tagging_id'),
          tags[:id].as('tag_id'),
          audio_recordings[:recorded_date],
          audio_recordings[:duration_seconds],
          provenance[:score_minimum].as('provenance_score_minimum'),
          provenance[:score_maximum].as('provenance_score_maximum'),
          analysis_jobs_items[:result].as('result')
        ]
      end

      def self.analysis_jobs_items = AnalysisJobsItem.arel_table
      def self.audio_recordings = AudioRecording.arel_table
      def self.audio_events = AudioEvent.arel_table
      def self.provenance = Provenance.arel_table
      def self.taggings = Tagging.arel_table
      def self.tags = Tag.arel_table
      def self.regions = Region.arel_table
      def self.sites = Site.arel_table

      def self.audio_recording_end_date
        'audio_recordings.recorded_date + CAST(audio_recordings.duration_seconds || \' seconds\' as interval) AS end_date'
      end
    end
  end
end
