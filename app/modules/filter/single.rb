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

    attr_reader :table

    def initialize(model, filter_settings)
      @table = relation_table(model)
      @initial_query = relation_all(model)
      validate_filter_settings(filter_settings)

      # we really only care about a small subset of the filter settings
      # the default fields to render
      @render_fields = filter_settings[:render_fields].map(&:to_sym)
      # and the custom fields
      @custom_fields2 = filter_settings[:custom_fields2] || {}

      # the intersection of the above is what we have to pull out of the db
    end

    # return the constructed query
    # @return [ActiveRecord::Relation] query
    def query
      query = @initial_query.dup

      query_additional_fields(query)
    end

    private

    # @param [ActiveRecord::Relation] query - the query to modify
    # @return [ActiveRecord::Relation] the modified query
    def query_additional_fields(query)
      # select  all the default fields
      projections = [Arel.star]
      # also select any fields that are in the render filter setting and append them on
      @custom_fields2.each do |key, _value|
        # if a custom field is not in render, then we assume it is not rendered by default
        next unless @render_fields.include?(key)

        projections.push(project_custom_field(@table, key))
      end

      projections = projections.flatten.compact

      apply_projections(query, projections)
    end
  end
end
