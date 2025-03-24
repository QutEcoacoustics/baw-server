# frozen_string_literal: true

module AudioEventReporter
  # AudioEventReport::Report class builds an SQL query using Arel
  class Report
    # @param filter_params [ActionController::Parameters] the filter parameters
    # @param base_scope [ActiveRecord::Relation] the base scope for the query
    def initialize(filter_params, base_scope)
      filtered_base = filter_as_relation(filter_params, base_scope)

      attributes = [
        sites[:id].as('site_ids'),
        tags[:id].as('tag_ids'),
        audio_events[:audio_recording_id].as('audio_recording_ids')
      ]

      base = filtered_base.arel.project(attributes)

      base.join(taggings)
        .on(audio_events[:id].eq(taggings[:audio_event_id]))
        .join(tags)
        .on(taggings[:tag_id].eq(tags[:id]))

      @cte_table = Arel::Table.new('filtered_basis')
      @cte = Arel::Nodes::As.new(@cte_table, base)
      @query = Arel::SelectManager.new.with(@cte)
    end

    def generate
      aggregate_distinct(:site_ids)
      aggregate_distinct(:audio_recording_ids)
      aggregate_distinct(:tag_ids)
      @query.to_sql
    end

    # @param filter_params [ActionController::Parameters] the filter parameters
    # @param base_scope [ActiveRecord::Relation] the base scope for the query
    def filter_as_relation(filter_params, base_scope)
      filter_params_hash = filter_params_to_hash(filter_params)
      filter_query = Filter::Query.new(
        filter_params_hash,
        base_scope,
        AudioEvent,
        AudioEvent.filter_settings
      )
      filter_query.query_without_paging_sorting
    end

    # Get an aggregated array of distinct values for a field, as a new
    # projection on the main query instance variable.
    # @param field [Symbol] the field to aggregate
    def aggregate_distinct(field)
      distinct_query = Arel::SelectManager.new(@cte_table)
        .project(@cte_table[field])
        .distinct
        .as('distinct_sub')

      distinct_sub_table = Arel::Table.new('distinct_sub')

      array_agg_query = Arel::SelectManager.new
        .from(distinct_query)
        .project(distinct_sub_table[field].array_agg.as(field.to_s))

      @query.project(array_agg_query)
    end

    def filter_params_to_hash(params)
      params_hash = params.to_h if params.is_a? ActionController::Parameters
      return params_hash if params_hash.is_a? ActiveSupport::HashWithIndifferentAccess

      raise ArgumentError,
        'params needs to be HashWithIndifferentAccess \
         or an ActionController::Parameters'
    end

    def audio_events
      AudioEvent.arel_table
    end

    def audio_recordings
      AudioRecording.arel_table
    end

    def sites
      Site.arel_table
    end

    def regions
      Region.arel_table
    end

    def tags
      Tag.arel_table
    end

    def taggings
      Tagging.arel_table
    end
  end
end
