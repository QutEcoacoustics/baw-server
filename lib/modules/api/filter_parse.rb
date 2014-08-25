require 'active_support/concern'

module Api

  # Provides support for parsing a query from a hash.
  module FilterParse
    extend ActiveSupport::Concern
    extend Validate

    private

    # Append sorting to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] params
    # @param [Symbol] default_order_by
    # @param [Symbol] default_direction
    # @return [ActiveRecord::Relation] the modified query
    def build_sort(query, params, default_order_by, default_direction)
      result = parse_sort(params, default_order_by, default_direction)
      compose_sort(query, @table, result.order_by.to_sym, @valid_fields, result.direction.to_sym)
    end

    # Append paging to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] params
    # @return [ActiveRecord::Relation] the modified query
    def build_paging(query, params)
      result = parse_paging(params)
      compose_paging(query, result.offset, result.limit)
    end

    # Add conditions to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Array<Arel::Nodes::Node>] conditions
    # @return [ActiveRecord::Relation] the modified query
    def add_conditions(query, conditions)
      conditions.each do |condition|
        query = query.where(condition)
      end
      query
    end

    # Add condition to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Arel::Nodes::Node] condition
    # @return [ActiveRecord::Relation] the modified query
    def add_condition(query, condition)
        query.where(condition)
    end

    # Build conditions.
    # @param [Symbol] field
    # @param [Hash] hash
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Array<Arel::Nodes::Node>] conditions
    def build_conditions(field, hash, table, valid_fields)
      fail ArgumentError, "Conditions hash must have at least 1 entry, got #{hash.size}." if hash.blank? || hash.size < 1
      conditions = []
      hash.each do |key, value|
        if key == :range
          # special case for range filter (Hash)
          conditions.push(build_range(field, value, table, valid_fields))
        elsif key == :in
          # special case for in filter (Array)
          conditions.push(build_in(field, value, table, valid_fields))
        elsif key == :not
          # negation
          conditions.push(*build_not(value, table, valid_fields))
        elsif value.is_a?(Hash)
          # recurse
          conditions.push(*build_conditions(key, value, table, valid_fields))
        elsif value.is_a?(Array)
          # combine conditions
          conditions.push(build_array(key, value, table, valid_fields))
        else
          # create base condition
          conditions.push(build_condition(field, key, value, table, valid_fields))
        end

      end

      conditions
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
        when :gt, :greater_than
          compose_gt(table, field, valid_fields, filter_value)
        when :lteq, :less_than_or_equal
          compose_lteq(table, field, valid_fields, filter_value)
        when :gteq, :greater_than_or_equal
          compose_gteq(table, field, valid_fields, filter_value)

        # subsets
        # range (from/to, interval), in are handled separately
        when :contains
          compose_contains(table, field, valid_fields, filter_value)
        when :starts_with
          compose_starts_with(table, field, valid_fields, filter_value)
        when :ends_with
          compose_ends_with(table, field, valid_fields, filter_value)
        #when :regex - not implemented in Arel 3.
        #  compose_regex(@table, field, @valid_columns, filter_value)

        else
          fail ArgumentError, "Unrecognised filter #{filter_name}."
      end
    end

    # Build a condition from an array.
    # @param [Symbol] filter_name
    # @param [Object] filter_value
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_array(filter_name, filter_value, table, valid_fields)
      conditions = []
      filter_value.each do |item|
        new_conditions = build_conditions(filter_name, item, table, valid_fields)
        conditions.push(*new_conditions)
      end

      build_combine(filter_name, conditions)
    end

    # Combine conditions.
    # @param [Symbol] filter_name
    # @param [Array<Arel::Nodes::Node>] conditions
    # @return [Arel::Nodes::Node] condition
    def build_combine(filter_name, conditions)
      fail ArgumentError, "Conditions array must have at least 2 entries, got #{conditions.size}." if conditions.blank? || conditions.size < 2
      condition_builder = nil
      conditions.each do |condition|
        if condition_builder.blank?
          condition_builder = condition

        else
          case filter_name
            when :and
              condition_builder = compose_and(condition_builder, condition)
            when :or
              condition_builder = compose_or(condition_builder, condition)
            else
              fail ArgumentError, "Unrecognised filter combiner #{filter_name}."
          end

        end
      end

      condition_builder
    end

    # Build a range condition.
    # @param [Symbol] field
    # @param [Object] filter_value
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_range(field, filter_value, table, valid_fields)
      from = filter_value[:from]
      to = filter_value[:to]
      interval = filter_value[:interval]

      if !from.blank? && !to.blank? && !interval.blank?
        fail ArgumentError, "Range filter must use either 'from' and 'to' or 'interval', not both."
      elsif from.blank? && !to.blank?
        fail ArgumentError, "Range filter missing 'from'."
      elsif !from.blank? && to.blank?
        fail ArgumentError, "Range filter missing 'to'."
      elsif !from.blank? && !to.blank?
        compose_range(table, field, valid_fields, from, to)
      elsif !interval.blank?
        compose_range_string(table, field, valid_fields, interval)
      else
        fail ArgumentError, 'Range filter was not valid.'
      end
    end

    # Build an in condition.
    # @param [Symbol] field
    # @param [Object] filter_value
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_in(field, filter_value, table, valid_fields)
      compose_in(table, field, valid_fields, filter_value)
    end

    # Build a not condition.
    # @param [Array<Hash>] value
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def build_not(value, table, valid_fields)
      conditions_to_negate = []
      value.each do |item|
        new_conditions = build_conditions(:not, item, table, valid_fields)
        conditions_to_negate.push(*new_conditions)
      end

      conditions = []

      conditions_to_negate.each do |condition|
        conditions.push(compose_not(condition))
      end

      conditions
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

      build_combine(:or, conditions)
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

      build_combine(:and, conditions)
    end

    def parse_paging(params)
      # qsp
      offset = params[:offset]
      limit = params[:limit]

      # POST body
      offset = params[:paging][:offset] if offset.blank? && !params[:paging].blank?
      limit = params[:paging][:limit] if limit.blank? && !params[:paging].blank?

      # default to first page with 50 per age
      offset = 0 if offset.blank?
      limit = validate_max_items if limit.blank?

      {offset: offset, limit: limit}
    end

    def parse_sort(params, default_order_by, default_direction)
      # qsp
      order_by = params[:order_by]
      direction = params[:direction]

      # POST body
      order_by = params[:sort][:order_by] if order_by.blank? && !params[:sort].blank?
      direction = params[:sort][:direction] if order_by.blank? && !params[:sort].blank?

      # default to reverse chronological
      order_by = default_order_by if order_by.blank?
      direction = default_direction if direction.blank?

      {order_by: order_by, direction: direction}
    end

    # Parse text from parameters.
    # @param [Hash] params
    # @param [Symbol] key
    # @return [String] condition
    def parse_qsp_text(params, key = :filter_partial_match)
      params[key].blank? ? nil : params[key]
    end

    # Get the QSPs from an object.
    # @param [Object] obj
    # @param [Object] value
    # @param [String] key_prefix
    # @param [Array<Symbol>] valid_fields
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp(obj, value, key_prefix, valid_fields, found = {})
      if value.is_a?(Hash)
        found = parse_qsp_hash(value, key_prefix, valid_fields, found)
      elsif value.is_a?(Array)
        found = parse_qsp_array(obj, value, key_prefix, valid_fields, found)
      else
        key_s = obj.blank? ? '' : obj.to_s
        is_filter_qsp = key_s.starts_with?(key_prefix)

        if is_filter_qsp
          new_key = key_s[key_prefix.size..-1].to_sym
          found[new_key] = value if valid_fields.include?(new_key)
        end
      end
      found
    end

    # Get the QSPs from a hash.
    # @param [Hash] hash
    # @param [String] key_prefix
    # @param [Array<Symbol>] valid_fields
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp_hash(hash, key_prefix, valid_fields, found = {})
      hash.each do |key, value|
        found = parse_qsp(key, value, key_prefix, valid_fields, found)
      end
      found
    end

    # Get the QSPs from an array.
    # @param [Object] key
    # @param [Array] array
    # @param [String] key_prefix
    # @param [Array<Symbol>] valid_fields
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp_array(key, array, key_prefix, valid_fields, found)
      array.each do |item|
        found = parse_qsp(key, item, key_prefix, valid_fields, found)
      end
      found
    end

  end
end