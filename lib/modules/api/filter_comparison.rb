require 'active_support/concern'

module Api

  # Provides comparisons for composing queries.
  module FilterComparison
    extend ActiveSupport::Concern
    extend Validate

    private

    # Create equals condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_eq(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      table[column_name].eq(value)
    end

    # Create not equals condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_eq(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      table[column_name].not_eq(value)
    end

    # Create less than condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_lt(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      table[column_name].lt(value)
    end

    # Create greater than condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_gt(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      table[column_name].gt(value)
    end

    # Create less than or equal condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_lteq(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      table[column_name].lteq(value)
    end

    # Create greater than or equal condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_gteq(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      table[column_name].gteq(value)
    end
  end
end