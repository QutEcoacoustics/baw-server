# frozen_string_literal: true

module Report
  module ArelHelpers
    module_function

    # Convenience function to create a CTE (Common Table Expression)
    # @param name [String] The name to use as the CTE table name
    # @param query [Arel::SelectManager] The query for the CTE
    # @return [Array] Table and CTE node
    def create_cte(name, query)
      # check that query is an Arel node
      # check if query inherits from Arel::Nodes
      raise ArgumentError, 'query must inherit from Arel::Expressions' unless query.is_a?(Arel::Expressions)

      table = Arel::Table.new(name)
      cte = Arel::Nodes::As.new(table, query)
      [table, cte]
    end

    # Aggregate distinct values for a field.
    # @param table [Arel::Table] The table to aggregate from
    # @param field [Symbol] The field to aggregate
    # @return [Arel::Nodes::NamedFunction] An aggregation node
    def aggregate_distinct(table, field)
      Arel::Nodes::NamedFunction.new(
        'ARRAY_AGG',
        [Arel::Nodes::SqlLiteral.new("DISTINCT #{table[field].name}")]
      )
    end

    # Creates a date range expression in SQL
    # @param start_expr [String] SQL expression for start time
    # @param end_expr [String] SQL expression for end time
    # @return [Arel::Nodes::SqlLiteral] SQL literal node
    def datetime_range_array(start_expr, end_expr)
      Arel.sql(
      <<~SQL.squish
        array_to_json(ARRAY[
           to_char(#{start_expr}, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           to_char(#{end_expr}, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         ])
      SQL
    ).as('range')
    end
  end
end
