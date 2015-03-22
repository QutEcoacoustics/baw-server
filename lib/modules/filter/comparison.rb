require 'active_support/concern'

module Filter

  # Provides comparisons for composing queries.
  module Comparison
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
      compose_eq_node(table[column_name], value)
    end

    # Create equals condition.
    # @param [Arel::Nodes::Node] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_eq_node(node, value)
      validate_node_or_attribute(node)
      node.eq(value)
    end

    # Create not equals condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_eq(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_not_eq_node(table[column_name], value)
    end

    # Create not equals condition.
    # @param [Arel::Nodes::Node] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_eq_node(node, value)
      validate_node_or_attribute(node)
      node.not_eq(value)
    end

    # Create less than condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_lt(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_lt_node(table[column_name], value)
    end

    # Create less than condition.
    # @param [Arel::Nodes::Node] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_lt_node(node, value)
      validate_node_or_attribute(node)
      node.lt(value)
    end

    # Create not less than condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_lt(table, column_name, allowed, value)
      compose_lt(table, column_name, allowed, value).not
    end

    # Create not less than condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_lt_node(node, value)
      compose_lt_node(node, value).not
    end

    # Create greater than condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_gt(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_gt_node(table[column_name], value)
    end

    # Create greater than condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_gt_node(node, value)
      validate_node_or_attribute(node)
      node.gt(value)
    end

    # Create not greater than condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_gt(table, column_name, allowed, value)
      compose_gt(table, column_name, allowed, value).not
    end

    # Create not greater than condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_gt_node(node, value)
      compose_gt_node(node, value).not
    end

    # Create less than or equal condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_lteq(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_lteq_node(table[column_name], value)
    end

    # Create less than or equal condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_lteq_node(node, value)
      validate_node_or_attribute(node)
      node.lteq(value)
    end

    # Create not less than or equal condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_lteq(table, column_name, allowed, value)
      compose_lteq(table, column_name, allowed, value).not
    end

    # Create not less than or equal condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_lteq_node(node, value)
      compose_lteq_node(node, value).not
    end

    # Create greater than or equal condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_gteq(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_gteq_node(table[column_name], value)
    end

    # Create greater than or equal condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_gteq_node(node, value)
      validate_node_or_attribute(node)
      node.gteq(value)
    end

    # Create not greater than or equal condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_gteq(table, column_name, allowed, value)
      compose_gteq(table, column_name, allowed, value).not
    end

    # Create not greater than or equal condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_gteq_node(node, value)
      compose_gteq_node(node, value).not
    end

  end
end