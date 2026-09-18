# frozen_string_literal: true

module Api
  # Lightweight statistics support for controllers.
  module Stats
    # Executes a stats query for a given model and request filter.
    #
    # Stats should be deliberately simpler than reports e.g. a handful of
    # aggregate projections over a permission-scoped, filtered query. An
    # optional hook can reshape the query before projections are
    # applied. For example, to add reselects or joins.
    #
    # @param base_query [ActiveRecord::Relation] permission-scoped query
    # @param model [Class] the ActiveRecord model base
    # @param projections [Hash{Symbol => Arel::Nodes::Node}] alias: expression
    #   pairs to be projected.
    # @param hook [#call, nil] optional callable that receives and transforms the
    #   filtered query before projections are applied.
    # @return [Array(Array<Hash>, Hash)] the query result and filter options
    def execute_stats(base_query:, model:, projections: {}, hook: nil)
      filter = Filter::Query.new(
        api_filter_params_filter_only!,
        base_query,
        model,
        model.filter_settings
      )

      # Preserving the supplied filter to later return in the response
      opts = {
        filter: filter.filter,
        filter_without_defaults: filter.supplied_filter
      }

      query = filter.query_without_paging_sorting.except(:select, :order, :limit, :offset)

      query = hook.call(query) if hook
      query = query.arel if query.is_a?(ActiveRecord::Relation)

      query.project(*projections.map { |name, expression| expression.as(name.to_s) })

      results = model.exec_query_casted(query)

      [results, opts]
    end
  end
end
