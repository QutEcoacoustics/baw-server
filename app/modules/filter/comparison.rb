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

    # Create case-insensitive equals condition.
    # Uses ILIKE (case-insensitive LIKE) with the value escaped so no wildcards are matched.
    # For nil values, falls back to an IS NULL check.
    # @param [Arel::Nodes::Node] node
    # @param [String, nil] value
    # @return [Arel::Nodes::Node] condition
    def compose_ieq_node(node, value)
      validate_node_or_attribute(node)
      return node.eq(nil) if value.nil?

      validate_string(value)
      sanitized_value = sanitize_like_value(value)
      node.matches(sanitized_value)
    end

    # Create case-insensitive not equals condition.
    # Uses NOT ILIKE with the value escaped so no wildcards are matched.
    # For nil values, falls back to an IS NOT NULL check.
    # @param [Arel::Nodes::Node] node
    # @param [String, nil] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_ieq_node(node, value)
      validate_node_or_attribute(node)
      return node.not_eq(nil) if value.nil?

      validate_string(value)
      sanitized_value = sanitize_like_value(value)
      node.does_not_match(sanitized_value)
    end
  end
end
