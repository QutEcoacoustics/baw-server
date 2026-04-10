# frozen_string_literal: true

module Api
  # Utilities for building, executing and rendering report queries within controllers.
  module Reporting
    # Applies request filters to base_query, passes the filtered relation
    # through a report template, then applies projections to the resulting
    # Arel query.
    #
    # @param base_query [ActiveRecord::Relation] permission-scoped query
    # @param template [#call] callable report template that defines the report's
    #   structure; must receive an ActiveRecord::Relation and return an
    #   Arel::SelectManager
    # @param projections [Hash{Symbol => Arel::Nodes::Node}] alias: expression
    #   pairs to project from template
    # @return [Array(Array<Hash>, Hash)] the query result and filter options
    def execute_report(base_query:, template:, projections: {})
      raise ArgumentError, 'template must respond to #call' unless template.respond_to?(:call)

      filter = Filter::Query.new(
        api_filter_params_filter_only!,
        base_query,
        AudioEvent,
        AudioEvent.filter_settings
      )

      # Preserving the supplied filter to later return in the response
      opts = {
        filter: filter.filter,
        filter_without_defaults: filter.supplied_filter
      }

      query = filter.query_without_paging_sorting
      query = template.call(query)
      query.project(*projections.map { |name, expression| expression.as(name.to_s) })

      results = AudioEvent.exec_query_casted(query)

      [results, opts]
    end

    def respond_report(result, opts = {})
      render_format(result, opts)
    end
  end
end
