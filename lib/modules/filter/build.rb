require 'active_support/concern'

module Filter

  # Provides support for parsing a query from a hash.
  module Build
    extend ActiveSupport::Concern
    extend Comparison
    extend Core
    extend Subset
    extend Validate

    private

    # Build conditions from a hash.
    # @param [Hash] hash
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Array<Arel::Nodes::Node>] conditions
    def build_top(hash, table, valid_fields)
      fail CustomErrors::FilterArgumentError.new("Conditions hash must have at least 1 entry, got #{hash.size}.", {hash: hash}) if hash.blank? || hash.size < 1
      conditions = []
      hash.each do |key, value|
        # combinators or fields can be at top level. Assumes 'and' (query.where(condition) uses 'and').

        built_conditions = build_hash(key, value, table, valid_fields)
        conditions.push(*built_conditions)
      end
      conditions
    end

    # Build conditions from a hash.
    # @param [Symbol] field
    # @param [Hash] hash
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Array<Arel::Nodes::Node>] conditions
    def build_hash(field, hash, table, valid_fields)
      fail CustomErrors::FilterArgumentError.new("Conditions hash must have at least 1 entry, got #{hash.size}.", {field: field, hash: hash}) if hash.blank? || hash.size < 1
      fail CustomErrors::FilterArgumentError.new("'Not' must have a single combiner or field name, got #{hash.size}", {field: field, hash: hash}) if field == :not && hash.size != 1
      conditions = []

      case field
        when :and, :or
          conditions_to_combine = build_hashes(hash, table, valid_fields)
          combined_conditions = build_combiner(field, conditions_to_combine)
          conditions.push(combined_conditions)
        else
          hash.each do |key, value|
            conditions.push(build_field(field, key, value, table, valid_fields))
          end
      end

      conditions
    end

    # Build conditions from nested hashes.
    # @param [Hash] hash
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Array<Arel::Nodes::Node>] conditions
    def build_hashes(hash, table, valid_fields)
      conditions = []
      hash.each do |key, value|
        built_conditions = build_hash(key, value, table, valid_fields)
        conditions.push(*built_conditions)
      end
      conditions
    end

    # Build a field condition.
    # @param [Symbol] field
    # @param [Symbol] key
    # @param [Object] value
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_field(field, key, value, table, valid_fields)
      case field
        when :not
          build_not(key, value, table, valid_fields)
        when *valid_fields
          build_condition(field, key, value, table, valid_fields)
        else
          fail CustomErrors::FilterArgumentError.new("Unrecognised combiner or field name: #{field}.")
      end
    end

    # Build multiple combiners or field conditions.
    # @param [Symbol] field
    # @param [Symbol] key
    # @param [Object] value
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_multiple(field, key, value, table, valid_fields)
      case field
        when :and, :or
          build_combiner(field, build_hash(key, value, table, valid_fields))
        else
          fail CustomErrors::FilterArgumentError.new("Unrecognised combiner or field name: #{field}", {field: key, hash: value})
      end
    end

    # Combine two conditions.
    # @param [Symbol] combiner
    # @param [Arel::Nodes::Node] condition1
    # @param [Arel::Nodes::Node] condition2
    # @return [Arel::Nodes::Node] condition
    def build_combiner_binary(combiner, condition1, condition2)
      case combiner
        when :and
          compose_and(condition1, condition2)
        when :or
          compose_or(condition1, condition2)
        else
          fail CustomErrors::FilterArgumentError.new("Unrecognised filter combiner #{combiner}.")
      end
    end

    # Combine conditions.
    # @param [Symbol] combiner
    # @param [Array<Arel::Nodes::Node>] conditions
    # @return [Arel::Nodes::Node] condition
    def build_combiner(combiner, conditions)
      fail CustomErrors::FilterArgumentError.new("Combiner '#{combiner}' must have at least 2 entries, got #{conditions.size}.") if conditions.blank? || conditions.size < 2
      combined_conditions = nil

      conditions.each do |condition|

        if combined_conditions.blank?
          combined_conditions = condition
        else
          combined_conditions = build_combiner_binary(combiner, combined_conditions, condition)
        end

      end

      combined_conditions
    end

    # Build a not condition.
    # @param [Symbol] field
    # @param [Hash] hash
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_not(field, hash, table, valid_fields)
      fail CustomErrors::FilterArgumentError.new("'Not' must have a single filter, got #{hash.size}.", {field:field, hash:hash}) if hash.size != 1
      negated_condition = nil

      hash.each do |key, value|
        condition = build_condition(field, key, value, table, valid_fields)
        negated_condition = compose_not(condition)
      end

      negated_condition
    end

    # Build a condition.
    # @param [Symbol] field
    # @param [Symbol] filter_name
    # @param [Object] filter_value
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_condition(field, filter_name, filter_value, table, valid_fields)
      case filter_name

        # comparisons
        when :eq, :equal
          compose_eq(table, field, valid_fields, filter_value)
        when :not_eq, :not_equal
          compose_not_eq(table, field, valid_fields, filter_value)
        when :lt, :less_than
          compose_lt(table, field, valid_fields, filter_value)
        when :not_lt, :not_less_than
          compose_not_lt(table, field, valid_fields, filter_value)
        when :gt, :greater_than
          compose_gt(table, field, valid_fields, filter_value)
        when :not_gt, :not_greater_than
          compose_not_gt(table, field, valid_fields, filter_value)
        when :lteq, :less_than_or_equal
          compose_lteq(table, field, valid_fields, filter_value)
        when :not_lteq, :not_less_than_or_equal
          compose_not_lteq(table, field, valid_fields, filter_value)
        when :gteq, :greater_than_or_equal
          compose_gteq(table, field, valid_fields, filter_value)
        when :not_gteq, :not_greater_than_or_equal
          compose_not_gteq(table, field, valid_fields, filter_value)

        # subsets
        when :range, :in_range
          compose_range_options(table, field, valid_fields, filter_value)
        when :not_range, :not_in_range
          compose_not_range_options(table, field, valid_fields, filter_value)
        when :in
          compose_in(table, field, valid_fields, filter_value)
        when :not_in
          compose_not_in(table, field, valid_fields, filter_value)
        when :contains, :contain
          compose_contains(table, field, valid_fields, filter_value)
        when :not_contains, :not_contain, :does_not_contain
          compose_not_contains(table, field, valid_fields, filter_value)
        when :starts_with, :start_with
          compose_starts_with(table, field, valid_fields, filter_value)
        when :not_starts_with, :not_start_with, :does_not_start_with
          compose_not_starts_with(table, field, valid_fields, filter_value)
        when :ends_with, :end_with
          compose_ends_with(table, field, valid_fields, filter_value)
        when :not_ends_with, :not_end_with, :does_not_end_with
          compose_not_ends_with(table, field, valid_fields, filter_value)
        #when :regex - not implemented in Arel 3.
        #  compose_regex(@table, field, @valid_columns, filter_value)

        else
          fail CustomErrors::FilterArgumentError.new("Unrecognised filter #{filter_name}.")
      end
    end

    # Build a text condition.
    # @param [String] text
    # @param [Array<Symbol>] text_fields
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_text(text, text_fields, table, valid_fields)
      conditions = []
      text_fields.each do |text_field|
        condition = compose_contains(table, text_field, valid_fields, text)
        conditions.push(condition)
      end

      if conditions.size > 1
        build_combiner(:or, conditions)
      else
        conditions[0]
      end
    end

    # Build an equality condition that matches specified value to specified fields.
    # @param [Hash] filter_hash
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_generic(filter_hash, table, valid_fields)
      conditions = []
      filter_hash.each do |key, value|
        conditions.push(build_condition(key, :eq, value, table, valid_fields))
      end

      if conditions.size > 1
        build_combiner(:and, conditions)
      else
        conditions[0]
      end

    end

    # Build projections from a hash.
    # @param [Hash] hash
    # @param [Array<Symbol>] valid_fields
    # @return [Array<Arel::Attributes::Attribute>] projections
    def build_projections(hash, table, valid_fields)
      fail CustomErrors::FilterArgumentError.new("Projections hash must have exactly 1 entry, got #{hash.size}.", {hash:hash}) if hash.blank? || hash.size != 1
      result = []
      hash.each do |key, value|
        fail CustomErrors::FilterArgumentError.new("Must be 'include' or 'exclude' at top level, got #{key}", {hash:hash}) unless [:include, :exclude].include?(key)
        result = build_projection(key, value, table, valid_fields)
      end
      result
    end

    # Build projection to include or exclude.
    # @param [Symbol] key
    # @param [Hash<Symbol>] value
    # @param [Array<Symbol>] valid_fields
    # @return [Array<Arel::Attributes::Attribute>] projections
    def build_projection(key, value, table, valid_fields)
      fail CustomErrors::FilterArgumentError.new('Must not contain duplicate fields.', {"#{key}" => value}) if value.uniq.length != value.length
      columns = []
      case key
        when :include
          fail CustomErrors::FilterArgumentError.new('Include must contain at least one field.') if value.blank?
          columns = value.map { |x| CleanParams.clean(x) }
        when :exclude
          fail CustomErrors::FilterArgumentError.new('Exclude must contain at least one field.') if value.blank?
          columns = valid_fields.reject { |item| value.include?(item) }.map { |x| CleanParams.clean(x) }
          fail CustomErrors::FilterArgumentError.new('Exclude must contain at least one field.') if columns.blank?
        else
          fail CustomErrors::FilterArgumentError.new("Unrecognised projection key #{key}.")
      end

      columns.map { |item|
        validate_column_name(item, valid_fields)
        table[item]
      }
    end

  end
end