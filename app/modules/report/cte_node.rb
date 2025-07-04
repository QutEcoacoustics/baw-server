# frozen_string_literal: true

module Report
  # Common Table Expressions (CTE).
  #
  # Combines an Arel::Table, Arel::Nodes::As CTE node, and optional
  # dependency list for managing CTE relationships.
  #
  # @see Report::TableExpression::Collection to manage multiple Datum objects
  class CteNode
    # @param table [Arel::Table] The CTE's table
    # @param select [Arel::SelectManager] Select manager for the CTE
    # @param dependencies [Array<Symbol>] Names of CTE dependencies
    def initialize(table:, select:, depends_on: [])
      @table = table
      @cte = select.as(table.name)
      @depends_on = depends_on
    end

    # @return [Arel::Table] The Arel table for the CTE
    attr_reader :table

    # @return [Arel::Nodes::As] The CTE node
    attr_reader :cte

    # @return [Array<Symbol>] The names of CTE dependencies
    attr_reader :depends_on
  end
end
