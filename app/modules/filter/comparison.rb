# frozen_string_literal: true

require 'active_support/concern'

module Filter
  # Provides comparisons for composing queries.
  module Comparison
    extend ActiveSupport::Concern
    extend Validate

    private

    # Create equals condition.
    # @param [Arel::Nodes::Node] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_eq_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)
      node.eq(value)
    end

    # Create not equals condition.
    # @param [Arel::Nodes::Node] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_eq_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)
      node.not_eq(value)
    end

    # Create less than condition.
    # @param [Arel::Nodes::Node] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_lt_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)
      node.lt(value)
    end

    # Create not less than condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_lt_node(node, value)
      compose_lt_node(node, value).not
    end

    # Create greater than condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_gt_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)
      node.gt(value)
    end

    # Create not greater than condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_gt_node(node, value)
      compose_gt_node(node, value).not
    end

    # Create less than or equal condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_lteq_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)
      node.lteq(value)
    end

    # Create not less than or equal condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_lteq_node(node, value)
      compose_lteq_node(node, value).not
    end

    # Create greater than or equal condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_gteq_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)
      node.gteq(value)
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
