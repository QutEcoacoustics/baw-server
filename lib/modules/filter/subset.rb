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
      sanitized_value = sanitize_like_value(value)
      contains_value = "%#{sanitized_value}%"
      table[column_name].matches(contains_value)
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

    # Create starts_with condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_starts_with(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      sanitized_value = sanitize_like_value(value)
      contains_value = "#{sanitized_value}%"
      table[column_name].matches(contains_value)
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

    # Create ends_with condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_ends_with(table, column_name, allowed, value)
      validate_table_column(table, column_name, allowed)
      sanitized_value = sanitize_like_value(value)
      contains_value = "%#{sanitized_value}"
      table[column_name].matches(contains_value)
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

    # Create IN condition.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Array] values
    # @return [Arel::Nodes::Node] condition
    def compose_in(table, column_name, allowed, values)
      validate_levels(values)
      validate_table_column(table, column_name, allowed)
      validate_array_items(values)
      table[column_name].in(values)
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

    # Create IN condition using range.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Hash] hash
    # @return [Arel::Nodes::Node] condition
    def compose_range_options(table, column_name, allowed, hash)
      from = hash[:from]
      to = hash[:to]
      interval = hash[:interval]

      if !from.blank? && !to.blank? && !interval.blank?
        fail CustomErrors::FilterArgumentError.new("Range filter must use either ('from' and 'to') or ('interval'), not both.", {field: column_name, hash: hash})
      elsif from.blank? && !to.blank?
        fail CustomErrors::FilterArgumentError.new("Range filter missing 'from'.", {field: column_name, hash: hash})
      elsif !from.blank? && to.blank?
        fail CustomErrors::FilterArgumentError.new("Range filter missing 'to'.", {field: column_name, hash: hash})
      elsif !from.blank? && !to.blank?
        compose_range(table, column_name, allowed, from, to)
      elsif !interval.blank?
        compose_range_string(table, column_name, allowed, interval)
      else
        fail CustomErrors::FilterArgumentError.new("Range filter was not valid (#{hash})", {field: column_name, hash: hash})
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

    # Create IN condition using range.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] range_string
    # @return [Arel::Nodes::Node] condition
    def compose_range_string(table, column_name, allowed, range_string)
      validate_table_column(table, column_name, allowed)

      range_regex = /(\[|\()(.*),(.*)(\)|\])/i
      matches = range_string.match(range_regex)
      fail CustomErrors::FilterArgumentError.new("Range string must be in the form (|[.*,.*]|), got #{range_string.inspect}", {field: column_name}) unless matches

      captures = matches.captures

      # get ends spec's and values
      start_exclude = captures[0] == ')'
      start_value = captures[1]
      end_value = captures[2]
      end_exclude = captures[3] == ')'

      # build using gt, lt, gteq, lteq
      if start_exclude
      start_condition = table[column_name].gt(start_value)
      else
        start_condition =table[column_name].gteq(start_value)
      end

      if end_exclude
        end_condition = table[column_name].lt(end_value)
      else
        end_condition =table[column_name].lteq(end_value)
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

    # Create IN condition using from (inclusive) and to (exclusive).
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] from
    # @param [Object] to
    # @return [Arel::Nodes::Node] condition
    def compose_range(table, column_name, allowed, from, to)
      validate_table_column(table, column_name, allowed)
      range = Range.new(from, to, true)
      table[column_name].in(range)
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

    # Create regular expression condition.
    # Not available just now, maybe in Arel 6?
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_regex(table, column_name, allowed, value)
      fail NotImplementedError
      validate_table_column(table, column_name, allowed)
      table[column_name] =~ value
    end

    # Create negated regular expression condition.
    # Not available just now, maybe in Arel 6?
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Object] value
    # @return [Arel::Nodes::Node] condition
    def compose_not_regex(table, column_name, allowed, value)
      compose_regex(table, column_name, allowed, value).not
    end

  end
end