# frozen_string_literal: true

require 'active_support/concern'

module Filter
  # Provides subset filtering (contains, in, range) for composing queries.
  module Subset
    extend ActiveSupport::Concern
    extend Validate

    private

    # Create contains condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_contains(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_contains_node(table[column_name], value)
    end

    # Create contains condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_contains_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)

      string_value = ActiveRecord::Base.connection.type_cast(value)
      sanitized_value = sanitize_like_value(string_value)

      # if we're querying against a json/jsonb column, then first cast column to json
      node = node.cast('text') if json_column?(node)

      contains_value = "%#{sanitized_value}%"
      node.matches(contains_value)
    end

    # Create not contains condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_contains(table, column_name, allowed, value)
      compose_contains(table, column_name, allowed, value).not
    end

    # Create not contains condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_contains_node(node, value)
      compose_contains_node(node, value).not
    end

    # Create starts_with condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_starts_with(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_starts_with_node(table[column_name], value)
    end

    # Create starts_with condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_starts_with_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)
      sanitized_value = sanitize_like_value(value)
      contains_value = "#{sanitized_value}%"
      node.matches(contains_value)
    end

    # Create not starts_with condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_starts_with(table, column_name, allowed, value)
      compose_starts_with(table, column_name, allowed, value).not
    end

    # Create not starts_with condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_starts_with_node(node, value)
      compose_starts_with_node(node, value).not
    end

    # Create ends_with condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_ends_with(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_ends_with_node(table[column_name], value)
    end

    # Create ends_with condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_ends_with_node(node, value)
      validate_node_or_attribute(node)
      validate_basic_class(node, value)
      sanitized_value = sanitize_like_value(value)
      contains_value = "%#{sanitized_value}"
      node.matches(contains_value)
    end

    # Create not ends_with condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_ends_with(table, column_name, allowed, value)
      compose_ends_with(table, column_name, allowed, value).not
    end

    # Create not ends_with condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_ends_with_node(node, value)
      compose_ends_with_node(node, value).not
    end

    # Create IN condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Array] values
    # @return [Arel::Nodes::Node] condition
    def compose_in(table, column_name, allowed, values)
      validate_table_column(table, column_name, allowed)
      compose_in_node(table[column_name], values)
    end

    # Create IN condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Array] values
    # @return [Arel::Nodes::Node] condition
    def compose_in_node(node, values)
      validate_node_or_attribute(node)
      validate_array(values)
      validate_array_items(values) if values.is_a?(Array)
      node.in(values)
    end

    # Create NOT IN condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Array] values
    # @return [Arel::Nodes::Node] condition
    def compose_not_in(table, column_name, allowed, values)
      compose_in(table, column_name, allowed, values).not
    end

    # Create NOT IN condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Array] values
    # @return [Arel::Nodes::Node] condition
    def compose_not_in_node(node, values)
      compose_in_node(node, values).not
    end

    # Create IN condition using range.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Hash] hash
    # @return [Arel::Nodes::Node] condition
    def compose_range_options(table, column_name, allowed, hash)
      validate_table_column(table, column_name, allowed)
      compose_range_options_node(table[column_name], hash)
    end

    # Create IN condition using range.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Hash] hash
    # @return [Arel::Nodes::Node] condition
    def compose_range_options_node(node, hash)
      unless hash.is_a?(Hash)
        raise CustomErrors::FilterArgumentError,
          "Range filter must be {'from': 'value', 'to': 'value'} or {'interval': 'value'} got #{hash}"
      end

      from = hash[:from]
      to = hash[:to]
      interval = hash[:interval]

      if from.present? && to.present? && interval.present?
        raise CustomErrors::FilterArgumentError.new(
          "Range filter must use either ('from' and 'to') or ('interval'), not both.", { hash: hash }
        )
      elsif from.blank? && to.present?
        raise CustomErrors::FilterArgumentError.new("Range filter missing 'from'.", { hash: hash })
      elsif from.present? && to.blank?
        raise CustomErrors::FilterArgumentError.new("Range filter missing 'to'.", { hash: hash })
      elsif from.present? && to.present?
        compose_range_node(node, from, to)
      elsif interval.present?
        compose_range_string_node(node, interval)
      else
        raise CustomErrors::FilterArgumentError.new("Range filter was not valid (#{hash})", { hash: hash })
      end
    end

    # Create NOT IN condition using range.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Hash] hash
    # @return [Arel::Nodes::Node] condition
    def compose_not_range_options(table, column_name, allowed, hash)
      compose_range_options(table, column_name, allowed, hash).not
    end

    # Create NOT IN condition using range.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Hash] hash
    # @return [Arel::Nodes::Node] condition
    def compose_not_range_options_node(node, hash)
      compose_range_options_node(node, hash).not
    end

    # Create IN condition using range.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] range_string
    # @return [Arel::Nodes::Node] condition
    def compose_range_string(table, column_name, allowed, range_string)
      validate_table_column(table, column_name, allowed)
      compose_range_string_node(table[column_name], range_string)
    end

    # Create IN condition using range.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [String] range_string
    # @return [Arel::Nodes::Node] condition
    def compose_range_string_node(node, range_string)
      validate_node_or_attribute(node)

      range_regex = /(\[|\()(.*),(.*)(\)|\])/i
      matches = range_string.match(range_regex)
      unless matches
        raise CustomErrors::FilterArgumentError.new(
          "Range string must be in the form (|[.*,.*]|), got #{range_string.inspect}", { field: column_name }
        )
      end

      captures = matches.captures

      # get ends spec's and values
      start_exclude = captures[0] == ')'
      start_value = captures[1]
      end_value = captures[2].strip
      end_exclude = captures[3] == ')'

      # build using gt, lt, gteq, lteq
      start_condition = if start_exclude
                          node.gt(start_value)
                        else
                          node.gteq(start_value)
                        end

      end_condition = if end_exclude
                        node.lt(end_value)
                      else
                        node.lteq(end_value)
                      end

      start_condition.and(end_condition)
    end

    # Create NOT IN condition using range.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] range_string
    # @return [Arel::Nodes::Node] condition
    def compose_not_range_string(table, column_name, allowed, range_string)
      compose_range_string(table, column_name, allowed, range_string).not
    end

    # Create NOT IN condition using range.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [String] range_string
    # @return [Arel::Nodes::Node] condition
    def compose_not_range_string_node(node, range_string)
      compose_range_string_node(node, range_string).not
    end

    # Create IN condition using from (inclusive) and to (exclusive).
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] from
    # @param [Object] to
    # @return [Arel::Nodes::Node] condition
    def compose_range(table, column_name, allowed, from, to)
      validate_table_column(table, column_name, allowed)
      compose_range_node(table[column_name], from, to)
    end

    # Create IN condition using from (inclusive) and to (exclusive).
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] from
    # @param [Object] to
    # @return [Arel::Nodes::Node] condition
    def compose_range_node(node, from, to)
      validate_node_or_attribute(node)
      validate_basic_class(node, from)
      validate_basic_class(node, to)

      range = Range.new(from, to, true)
      node.in(range)
    end

    # Create NOT IN condition using from (inclusive) and to (exclusive).
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] from
    # @param [Object] to
    # @return [Arel::Nodes::Node] condition
    def compose_not_range(table, column_name, allowed, from, to)
      compose_range(table, column_name, allowed, from, to).not
    end

    # Create NOT IN condition using from (inclusive) and to (exclusive).
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] from
    # @param [Object] to
    # @return [Arel::Nodes::Node] condition
    def compose_not_range_node(node, from, to)
      compose_range_node(node, from, to).not
    end

    # Create regular expression condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_regex(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_regex_node(table[column_name], value)
    end

    # Create regular expression condition.
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_regex_node(node, value)
      validate_node_or_attribute(node)
      validate_string(value)
      Arel::Nodes::Regexp.new(node, Arel::Nodes.build_quoted(value))
    end

    # Create negated regular expression condition.
    # Not available just now, maybe in Arel 6?
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_regex(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      compose_not_regex_node(table[column_name], value)
    end

    # Create negated regular expression condition.
    # Not available just now, maybe in Arel 6?
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_regex_node(node, value)
      validate_node_or_attribute(node)
      validate_string(value)
      Arel::Nodes::NotRegexp.new(node, Arel::Nodes.build_quoted(value))
    end
  end
end
