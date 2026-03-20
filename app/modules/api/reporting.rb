# frozen_string_literal: true

module Api
  module Reporting
    def execute_report(base_query:, template: nil, projections: {}, joins: {}, options: {})
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

      query = query.joins(joins)

      # Is this useful? e.g. a reporting action that only injects projections and
      # doesn't need a template to work
      query = template.call(query, options) if template

      # TODO: This is where you would add projections like group_by does
      #

      results = AudioEvent.exec_query_casted(query)
      [results, opts]
    end

    def respond_report(result, opts = {})
      render_format(result, opts)
    end
  end
end
