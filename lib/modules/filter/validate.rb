# use include, not extend in host classes
require 'active_support/concern'

# Provides common validations for composing queries.
module Filter
  module Validate
    extend ActiveSupport::Concern

    # using Arel https://github.com/rails/arel
    # http://robots.thoughtbot.com/using-arel-to-compose-sql-queries
    # http://jpospisil.com/2014/06/16/the-definitive-guide-to-arel-the-sql-manager-for-ruby.html

    private

    # Validate sorting values.
    # @param [Symbol] order_by
    # @param [Array<Symbol>] valid_fields
    # @param [Symbol] direction
    # @raise [ArgumentError] if order_by is not valid
    # @return [void]
    def validate_sorting(order_by, valid_fields, direction)
      if !order_by.blank? && !direction.blank?
        # allow both to be nil, but if one is nil and the other is not, that is an error.
        fail ArgumentError, 'Order by must not be null' if order_by.blank?
        fail ArgumentError, 'Direction must not be null' if direction.blank?
        fail ArgumentError, 'Valid Fields must not be null' if valid_fields.blank?

        direction_sym = direction.to_sym
        order_by_sym = order_by.to_sym
        valid_fields_sym = valid_fields.map(&:to_sym)

        fail ArgumentError, "Order by must be in #{valid_fields_sym.inspect}, got #{order_by_sym.inspect}" unless valid_fields_sym.include?(order_by_sym)
        fail ArgumentError, "Direction must be asc or desc, got #{direction_sym.inspect}" unless [:desc, :asc].include?(direction_sym)
      end
    end

    # Validate paging values.
    # @param [Integer] offset
    # @param [Integer] limit
    # @param [Integer] max_limit
    # @return [void]
    def validate_paging(offset, limit, max_limit)
      if !offset.blank? && !limit.blank?
        # allow both to be nil, but if one is nil and the other is not, that is an error.
        fail ArgumentError, "Offset must be an integer, got #{offset.inspect}" if offset.blank? || offset != offset.to_i
        fail ArgumentError, "Limit must be an integer, got #{limit.inspect}" if limit.blank? || limit != limit.to_i
        fail ArgumentError, "Max must be an integer, got #{max_limit.inspect}" if max_limit.blank? || max_limit != max_limit.to_i

        offset_i = offset.to_i
        limit_i = limit.to_i
        max_limit_i = max_limit.to_i

        fail ArgumentError, "Offset must be 0 or greater, got #{offset_i.inspect}" if offset_i < 0
        fail ArgumentError, "Limit must be greater than 0, got #{limit_i.inspect}" if limit_i < 1
        fail ArgumentError, "Max must be greater than 0, got #{max_limit_i.inspect}" if max_limit_i < 1
      end
    end

    # Validate paging values.
    # @param [Integer] page
    # @param [Integer] items
    # @param [Integer] max_items
    # @return [void]
    def validate_paging_external(page, items, max_items)
      if !page.blank? && !items.blank?
        # allow both to be nil, but if one is nil and the other is not, that is an error.
        fail ArgumentError, "Page must be an integer, got #{page.inspect}" if page.blank? || page != page.to_i
        fail ArgumentError, "Items must be an integer, got #{items.inspect}" if items.blank? || items != items.to_i
        fail ArgumentError, "Max must be an integer, got #{max_items.inspect}" if max_items.blank? || max_items != max_items.to_i

        page_i = page.to_i
        items_i = items.to_i
        max_items_i = max_items.to_i

        fail ArgumentError, "Page must be greater than 0, got #{page_i.inspect}" if page_i < 1
        fail ArgumentError, "Items must be greater than 0, got #{items_i.inspect}" if items_i < 1
        fail ArgumentError, "Max must be greater than 0, got #{max_items_i.inspect}" if max_items_i < 1
      end
    end

    # Validate query, table, and column values.
    # @param [Arel::Query] query
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @return [void]
    def validate_query_table_column(query, table, column_name, allowed)
      validate_query(query)
      validate_table(table)
      validate_column_name(column_name, allowed)
    end

    # Validate table and column values.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @return [void]
    def validate_table_column(table, column_name, allowed)
      validate_table(table)
      validate_column_name(column_name, allowed)
    end

    # Validate query and hash values.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] hash
    # @return [void]
    def validate_query_hash(query, hash)
      validate_query(query)
      validate_hash(hash)
    end

    # Validate table value.
    # @param [Arel::Table] table
    # @raise [ArgumentError] if table is not an Arel::Table
    # @return [void]
    def validate_table(table)
      fail ArgumentError, "Table must be Arel::Table, got #{table.inspect}" unless table.is_a?(Arel::Table)
    end

    # Validate table value.
    # @param [ActiveRecord::Relation] query
    # @raise [ArgumentError] if query is not an Arel::Query
    # @return [void]
    def validate_query(query)
      fail ArgumentError, "Query must be ActiveRecord::Relation, got #{query.inspect}" unless query.is_a?(ActiveRecord::Relation)
    end

    # Validate condition value.
    # @param [Arel::Nodes::Node] condition
    # @raise [ArgumentError] if condition is not an Arel::Nodes::Node
    # @return [void]
    def validate_condition(condition)
      fail ArgumentError, "Condition must be Arel::Nodes::Node, got #{condition.inspect}" unless condition.is_a?(Arel::Nodes::Node)
    end

    # Validate projection value.
    # @param [Arel::Attributes::Attribute] projection
    # @raise [ArgumentError] if projection is not an Arel::Attributes::Attribute
    # @return [void]
    def validate_projection(projection)
      fail ArgumentError, "Condition must be Arel::Attributes::Attribute, got #{projection.inspect}" unless projection.is_a?(Arel::Attributes::Attribute)
    end

    # Validate column name value.
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @raise [ArgumentError] if column name is not a symbol in allowed
    # @return [void]
    def validate_column_name(column_name, allowed)
      fail ArgumentError, "Column name must not be null, got #{column_name.inspect}" if column_name.blank?
      fail ArgumentError, "Column name must be a symbol, got #{column_name.inspect}" unless column_name.is_a?(Symbol)
      fail ArgumentError, "Allowed must be an Array, got #{allowed.inspect}" unless allowed.is_a?(Array)
      fail ArgumentError, "Column name must be in #{allowed.inspect}, got #{column_name.inspect}" unless allowed.include?(column_name)
    end

    # Validate model value.
    # @param [ActiveRecord::Base] model
    # @raise [ArgumentError] if model is not an ActiveRecord::Base
    # @return [void]
    def validate_model(model)
      fail ArgumentError, "Model must respond to scoped, got #{model.inspect}" unless model.respond_to?(:scoped)
    end

    # Validate an array.
    # @param [Array] value
    # @raise [ArgumentError] if value is not a valid Array.
    # @return [void]
    def validate_array(value)
      fail ArgumentError, "Value must not be null, got #{value.inspect}" if value.blank?
      fail ArgumentError, "Value must be an Array, got #{value.inspect}" unless value.is_a?(Array)
    end

    # Validate a hash.
    # @param [Array] value
    # @raise [ArgumentError] if value is not a valid Hash.
    # @return [void]
    def validate_hash(value)
      fail ArgumentError, "Value must not be null, got #{value.inspect}" if value.blank?
      fail ArgumentError, "value must be a Hash, got #{value.inspect}" unless value.is_a?(Hash)
    end

    # Validate Extract field for timestamp, time, interval, date.
    # @param [String] value
    # @raise [ArgumentError] if value is not a valid field value.
    # @return [void]
    def validate_projection_extract(value)
      valid = [
          :century, :day, :decade, :dow, :epoch, :hour,
          :isodow, :isoyear, :microseconds, :millennium,
          :milliseconds, :minute, :month, :quarter,
          :second, :timezone, :timezone_hour, :timezone_minute,
          :week, :year
      ]
      fail ArgumentError, 'Value for extract must not be null' if value.blank?
      fail ArgumentError, "Value for extract must be in #{valid}, got #{value.inspect}" unless valid.include?(value.downcase.to_sym)
    end

    # Escape wildcards in like value..
    # @param [String] value
    # @return [String] sanitized value
    def sanitize_like_value(value)
      value.gsub(/[\\_%\|]/) { |x| "\\#{x}" }
    end

    # Escape meta-characters in SIMILAR TO value.
    # see http://www.postgresql.org/docs/9.3/static/functions-matching.html
    # @param [String] value
    # @return [String] sanitized value
    def sanitize_similar_to_value(value)
      value.gsub(/[\\_%\|\*\+\?\{\}\(\)\[\]]/) { |x| "\\#{x}" }
    end

    # Remove all except 0-9, a-z, _ from projection alias
    # @param [String] value
    # @return [String] sanitized value
    def sanitize_projection_alias(value)
      value.gsub(/[^0-9a-zA-Z_]/) { |x|}
    end

  end
end