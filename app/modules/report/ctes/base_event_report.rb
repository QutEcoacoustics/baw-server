# frozen_string_literal: true

module Report
  module Ctes
    # The base node for audio event reports
    #
    # Provides the minimum required fields and joins needed for other CTEs that build on this data.
    #
    # Immediate descendants / downstream nodes:
    #  @see Report::AudioEvents the root node for audio event reports
    #  @see Report::Ctes::BaseVerification
    #  @see Report::Ctes::BucketAllocate
    #  @see Report::Ctes::CompositionSeries
    #  @see Report::Ctes::SortTemporalEvents
    #  @see Report::Ctes::EventSummary::BinSeries
    #  @see Report::Ctes::EventSummary::ScoreHistogram
    class BaseEventReport < Report::Cte::NodeTemplate

      table_name :base_table

      options base_scope: -> { default_relation_scope }

      select do
        selection = joins.call(base_scope)
        selection.project(attributes)
      end

      # The starting point for building this Cte is an active record relation that includes audio_recordings and sites
      # tables. This is because the base_scope passed in from the controller will already have these joins applied (by
      # Access::ByPermission.audio_events). Otherwise, fall back to this default scope.
      #
      # ! This is convenient for testing but probably unsafe
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

      def self.attributes
        [
          AudioEvent.arel_start_absolute.as('start_time_absolute'),
          AudioRecording.arel_recorded_end_date.as('end_date'),
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
    end
  end
end
