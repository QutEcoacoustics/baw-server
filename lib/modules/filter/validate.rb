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
    # @raise [FilterArgumentError] if order_by is not valid
    # @return [void]
    def validate_sorting(order_by, valid_fields, direction)
      if !order_by.blank? && !direction.blank?
        # allow both to be nil, but if one is nil and the other is not, that is an error.
        fail CustomErrors::FilterArgumentError, 'Order by must not be null' if order_by.blank?
        fail CustomErrors::FilterArgumentError, 'Direction must not be null' if direction.blank?
        fail CustomErrors::FilterArgumentError, 'Valid Fields must not be null' if valid_fields.blank?

        direction_sym = direction.to_sym
        order_by_sym = order_by.to_sym
        valid_fields_sym = valid_fields.map(&:to_sym)

        fail CustomErrors::FilterArgumentError, "Order by must be in #{valid_fields_sym}, got #{order_by_sym}" unless valid_fields_sym.include?(order_by_sym)
        fail CustomErrors::FilterArgumentError, "Direction must be asc or desc, got #{direction_sym}" unless [:desc, :asc].include?(direction_sym)
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
        fail CustomErrors::FilterArgumentError, "Offset must be an integer, got #{offset}" if offset.blank? || offset != offset.to_i
        fail CustomErrors::FilterArgumentError, "Limit must be an integer, got #{limit}" if limit.blank? || limit != limit.to_i
        fail CustomErrors::FilterArgumentError, "Max must be an integer, got #{max_limit}" if max_limit.blank? || max_limit != max_limit.to_i

        offset_i = offset.to_i
        limit_i = limit.to_i
        max_limit_i = max_limit.to_i

        fail CustomErrors::FilterArgumentError, "Offset must be 0 or greater, got #{offset_i}" if offset_i < 0
        fail CustomErrors::FilterArgumentError, "Limit must be greater than 0, got #{limit_i}" if limit_i < 1
        fail CustomErrors::FilterArgumentError, "Max must be greater than 0, got #{max_limit_i}" if max_limit_i < 1
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
        fail CustomErrors::FilterArgumentError, "Page must be an integer, got #{page}" if page.blank? || page != page.to_i
        fail CustomErrors::FilterArgumentError, "Items must be an integer, got #{items}" if items.blank? || items != items.to_i
        fail CustomErrors::FilterArgumentError, "Max must be an integer, got #{max_items}" if max_items.blank? || max_items != max_items.to_i

        page_i = page.to_i
        items_i = items.to_i
        max_items_i = max_items.to_i

        fail CustomErrors::FilterArgumentError, "Page must be greater than 0, got #{page_i}" if page_i < 1
        fail CustomErrors::FilterArgumentError, "Items must be greater than 0, got #{items_i}" if items_i < 1
        fail CustomErrors::FilterArgumentError, "Max must be greater than 0, got #{max_items_i}" if max_items_i < 1
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
    # @raise [FilterArgumentError] if table is not an Arel::Table
    # @return [void]
    def validate_table(table)
      fail CustomErrors::FilterArgumentError, "Table must be Arel::Table, got #{table.class}" unless table.is_a?(Arel::Table)
    end

    # Validate table value.
    # @param [ActiveRecord::Relation] query
    # @raise [FilterArgumentError] if query is not an Arel::Query
    # @return [void]
    def validate_query(query)
      fail CustomErrors::FilterArgumentError, "Query must be ActiveRecord::Relation, got #{query.class}" unless query.is_a?(ActiveRecord::Relation)
    end

    # Validate condition value.
    # @param [Arel::Nodes::Node] condition
    # @raise [FilterArgumentError] if condition is not an Arel::Nodes::Node
    # @return [void]
    def validate_condition(condition)
      if !condition.is_a?(Arel::Nodes::Node) && !condition.is_a?(String)
        fail CustomErrors::FilterArgumentError, "Condition must be Arel::Nodes::Node or String, got #{condition}"
      end
    end

    # Validate projection value.
    # @param [Arel::Attributes::Attribute] projection
    # @raise [FilterArgumentError] if projection is not an Arel::Attributes::Attribute
    # @return [void]
    def validate_projection(projection)
      fail CustomErrors::FilterArgumentError, "Condition must be Arel::Attributes::Attribute, got #{projection}" unless projection.is_a?(Arel::Attributes::Attribute)
    end

    # Validate column name value.
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @raise [FilterArgumentError] if column name is not a symbol in allowed
    # @return [void]
    def validate_column_name(column_name, allowed)
      fail CustomErrors::FilterArgumentError, "Column name must not be null, got #{column_name}" if column_name.blank?
      fail CustomErrors::FilterArgumentError, "Column name must be a symbol, got #{column_name}" unless column_name.is_a?(Symbol)
      fail CustomErrors::FilterArgumentError, "Allowed must be an Array, got #{allowed}" unless allowed.is_a?(Array)
      fail CustomErrors::FilterArgumentError, "Column name must be in #{allowed}, got #{column_name}" unless allowed.include?(column_name)
    end

    # Validate model value.
    # @param [ActiveRecord::Base] model
    # @raise [FilterArgumentError] if model is not an ActiveRecord::Base
    # @return [void]
    def validate_model(model)
      fail CustomErrors::FilterArgumentError, "Model must respond to scoped, got #{model}" unless model.respond_to?(:scoped)
    end

    # Validate an array.
    # @param [Array, Arel::SelectManager] value
    # @raise [FilterArgumentError] if value is not a valid Array.
    # @return [void]
    def validate_array(value)
      fail CustomErrors::FilterArgumentError, "Value must not be null, got #{value}" if value.blank?
      fail CustomErrors::FilterArgumentError, "Value must be an Array or Arel::SelectManager, got #{value}" unless value.is_a?(Array) || value.is_a?(Arel::SelectManager)
    end

    # Validate a hash.
    # @param [Array] value
    # @raise [FilterArgumentError] if value is not a valid Hash.
    # @return [void]
    def validate_hash(value)
      fail CustomErrors::FilterArgumentError, "Value must not be null, got #{value}" if value.blank?
      fail CustomErrors::FilterArgumentError, "value must be a Hash, got #{value}" unless value.is_a?(Hash)
    end

    # Validate Extract field for timestamp, time, interval, date.
    # @param [String] value
    # @raise [FilterArgumentError] if value is not a valid field value.
    # @return [void]
    def validate_projection_extract(value)
      valid = [
          :century, :day, :decade, :dow, :epoch, :hour,
          :isodow, :isoyear, :microseconds, :millennium,
          :milliseconds, :minute, :month, :quarter,
          :second, :timezone, :timezone_hour, :timezone_minute,
          :week, :year
      ]
      fail CustomErrors::FilterArgumentError, 'Value for extract must not be null' if value.blank?
      fail CustomErrors::FilterArgumentError, "Value for extract must be in #{valid}, got #{value}" unless valid.include?(value.downcase.to_sym)
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

    # Check that value is a float.
    # @param [Object] value
    # @raise [FilterArgumentError] if value is not a float
    # @return [void]
    def validate_float(value)
      fail CustomErrors::FilterArgumentError, 'Must have a value, got blank' if value.blank?

      filtered = value.to_s.tr('^0-9.', '')
      fail CustomErrors::FilterArgumentError, "Value must be a float, got #{filtered}" if filtered != value
      fail CustomErrors::FilterArgumentError, "Value must be a float after conversion, got #{filtered}" if filtered != value.to_f

      value_f = filtered.to_f
      fail CustomErrors::FilterArgumentError, "Value must be greater than 0, got #{value_f}" if value_f <= 0

    end

  end
end