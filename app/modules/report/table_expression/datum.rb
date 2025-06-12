# frozen_string_literal: true

module Report
  module TableExpression
    # An abstraction for Common Table Expressions (CTE).
    #
    # Combines an Arel::Table, Arel::Nodes::As CTE node, and optional
    # dependency list for managing CTE relationships.
    #
    # @see Report::TableExpression::Collection to manage multiple Datum objects
    class Datum
      # @param table [Arel::Table] The CTE's table
      # @param cte [Arel::Nodes::As] The CTE node
      # @param dependencies [Array<Symbol>] Names of CTE dependencies
      def initialize(table, cte, depends_on = [])
        @table = table
        @cte = cte
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
end
