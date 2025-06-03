# frozen_string_literal: true

module Report
  module ArelHelpers
    module_function

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

    def arel_recorded_end_date(source)
      Arel::Nodes::SqlLiteral.new("#{source.name}.recorded_date + CAST(#{source.name}.duration_seconds || ' seconds' as interval)")
    end
  end
end
