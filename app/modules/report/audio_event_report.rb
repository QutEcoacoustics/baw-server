# frozen_string_literal: true

module Report
  class AudioEventReport < Base
    include Report::ArelHelpers

    private

    def build_query
      # time_series_config = TimeSeries.StartEndTime.call(parameters)
      base_query_joined = @base_query.arel
        .project(attributes)
        .tap { |q| add_joins(q) }

      base_table = Arel::Table.new('base_table')
      base_cte = Arel::Nodes::As.new(base_table, base_query_joined)

      query = Arel::SelectManager.new
      query
        .with(base_cte)
        .project(aggregate_distinct(base_table, :site_ids))
        .project(aggregate_distinct(base_table, :audio_recording_ids))
        .project(aggregate_distinct(base_table, :tag_ids))
        .project(aggregate_distinct(base_table, :provenance_ids))
        .from([base_table])
    end

    # @param filter_params [ActionController::Parameters] the filter parameters
    # @param base_scope [ActiveRecord::Relation] the base scope for the query
    def filter_as_relation(filter_params, base_scope)
      filter_query = Filter::Query.new(
        filter_params,
        base_scope,
        AudioEvent,
        AudioEvent.filter_settings
      )
      filter_query.query_without_paging_sorting
    end

    def audio_events = AudioEvent.arel_table
    def audio_recordings = AudioRecording.arel_table
    def sites = Site.arel_table
    def regions = Region.arel_table
    def tags = Tag.arel_table
    def taggings = Tagging.arel_table
    def provenance = Provenance.arel_table

    # Default attributes for projection
    # @return [Array<Arel::Attributes>] the attributes to select
    def attributes
      [
        sites[:id].as('site_ids'),
        tags[:id].as('tag_ids'),
        audio_events[:audio_recording_id].as('audio_recording_ids'),
        audio_events[:provenance_id].as('provenance_ids'),
        audio_events[:id].as('audio_event_id'),
        audio_recordings[:recorded_date],
        Arel::Nodes::SqlLiteral.new(start_time_absolute_expression),
        Arel::Nodes::SqlLiteral.new(end_time_absolute_expression)
      ]
    end

    def add_joins(query)
      query
        .join(Arel::Table.new(:taggings))
        .on(Arel::Table.new(:audio_events)[:id].eq(Arel::Table.new(:taggings)[:audio_event_id]))
        .join(Arel::Table.new(:tags))
        .on(Arel::Table.new(:taggings)[:tag_id].eq(Arel::Table.new(:tags)[:id]))
    end

    def start_time_absolute_expression
      'audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || \' seconds\' as interval) ' \
        'as start_time_absolute'
    end

    def end_time_absolute_expression
      'audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || \' seconds\' as interval) ' \
        'as end_time_absolute'
    end
  end
end
