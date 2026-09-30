# frozen_string_literal: true

module Api
  # Lightweight statistics support for controllers.
  module Stats
    # Executes a stats query for a given model and request filter.
    #
    # Stats should be deliberately simpler than reports e.g. a handful of
    # aggregate projections over a permission-scoped, filtered query. An
    # optional block can reshape the query before projections are applied.
    # For example, to add joins or additional ctes.
    #
    # @param base_query [ActiveRecord::Relation] permission-scoped query.
    # @param model [ApplicationRecord] the ActiveRecord model base.
    # @param projections [Hash{Symbol => Arel::Nodes::Node}] alias: expression
    #   pairs to be projected.
    #
    # @yield [query] optionally reshapes the filtered query before projections are applied.
    # @yieldparam query [ActiveRecord::Relation] the filtered query without paging or sorting.
    # @yieldreturn [ActiveRecord::Relation, Arel::SelectManager] the transformed query.
    #
    # @return [Array(Hash, Hash)] the query result and filter options.
    def execute_stats(base_query:, model:, projections: {})
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

      query = yield(query) if block_given?
      query = query.arel if query.is_a?(ActiveRecord::Relation)

      # Clear any existing projections to avoid conflicts with the new projections.
      query.projections = []

      query.project(*projections.map { |name, expression| expression.as(name.to_s) })

      results = model.exec_query_casted(query).sole

      [results, opts]
    end

    # A base table alias, to be used when a stats base_query is used as a subquery or CTE.
    # @return [Arel::Table] a table representing the base table of the query.
    def self.base_table
      Arel::Table.new('stats_base')
    end
  end
end
