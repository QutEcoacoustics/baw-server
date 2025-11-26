# frozen_string_literal: true

module  Filter
  # An alternative to Filter::Query designed to load a single relation
  # with no parameters.
  # It's main function is to load an object that is compatible with list
  # shape responses in single shape responses by including custom fields
  # as part of the default projection.
  class Single
    include Core
    include CustomField
    include Projection
    include Validate
    include Archivable

    attr_reader :table

    # The fields actually requested by any projection (default or not)
    # after flattening. If projection was not requested this will be equivalent to `render_fields`.
    # Nil if `query_projection` was not called.
    # @return [Set<Symbol>]
    attr_reader :projected_fields

    def initialize(parameters, model, filter_settings, base_query: nil)
      @model = model
      @table = relation_table(model)
      @initial_query = base_query || relation_all(model)
      validate_filter_settings(filter_settings)

      # we really only care about a small subset of the filter settings
      # the default fields to render
      @render_fields = filter_settings[:render_fields].map(&:to_sym)
      # and the custom fields
      @custom_fields2 = filter_settings[:custom_fields2] || {}
      set_archived_param(parameters)

      # the intersection of the above is what we have to pull out of the db
    end

    # return the constructed query
    # @return [ActiveRecord::Relation] query
    def query
      query = @initial_query.dup

      query = query_with_archived_if_appropriate(query)

      query_additional_fields(query)
    end

    private

    # @param [ActiveRecord::Relation] query - the query to modify
    # @return [ActiveRecord::Relation] the modified query
    def query_additional_fields(query)
      # select  all the default fields
      projections = [table[Arel.star]]
      # also select any fields that are in the render filter setting and append them on
      @custom_fields2.each_key do |key|
        # if a custom field is not in render, then we assume it is not rendered by default
        next unless @render_fields.include?(key)

        projections.push(project_custom_field(@table, key, @custom_fields2))
      end

      # set projected_fields to render_fields. This works pretty differently from
      # Filter::Query but it's equivalent because we don't allow customization of the
      # projection in this class.
      # If the above lines change, then this line should also change.
      @projected_fields = @render_fields.to_set

      apply_projections(query, projections)
    end
  end
end
