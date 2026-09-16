# frozen_string_literal: true

module Api
  module Stats
    # want to just yield something
    # and the idea being it should be as simple as it can be for basic use cases (e.g. audio events)
    # and still support more complex cases (verifications) that need to multiple CTEs etc.
    def execute_stats(base_query:, model:, template:, projections: {})
      raise ArgumentError, 'template must respond to #call' unless template.respond_to?(:call)

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

      # so need to reselect something or else you get .* and then you get errors like ... must appear in group by
      # other stats queries will need to reselect things e.g. if they need something from other tables
      debugger
      query = filter.query_without_paging_sorting
      query = query.except(:select, :order, :limit, :offset)

      # reselect to a specific set of base columns, like reports
      # or it could be where the entire stats query is injected if it's simple
      # or keep as select *, and stats always use it as a cte or subquery?
      cte = Arel::Nodes::As.new(Arel::Table.new('base'), query.arel)
      Arel::SelectManager.new.project(Arel.star).with(cte).from(Arel::Table.new('base'))

      # -----------
      #
      query = query.reselect(Verification.arel_table[:confirmed]).arel
      query = template.call(query)

      query.project(*projections.map { |name, expression| expression.as(name.to_s) })

      results = model.exec_query_casted(query)

      [results, opts]
    end
  end
end
