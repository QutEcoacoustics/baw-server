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
    # @return [void]
    def validate_paging(offset, limit)
      validate_integer(offset, 0)
      validate_integer(limit, 1)
    end

    def validate_integer(value, min = nil, max = nil)
      fail CustomErrors::FilterArgumentError, 'Value must not be blank' if value.blank?
      fail CustomErrors::FilterArgumentError, "Value must be an integer, got #{value}" if value.blank? || value != value.to_i

      value_i = value.to_i

      fail CustomErrors::FilterArgumentError, "Value must be #{min} or greater, got #{value_i}" if !min.blank? && value_i < min
      fail CustomErrors::FilterArgumentError, "Value must be #{max} or less, got #{value_i}" if !max.blank? && value_i > max
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
      validate_name(column_name, allowed)
    end

    # Validate table and column values.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @return [void]
    def validate_table_column(table, column_name, allowed)
      validate_table(table)
      validate_name(column_name, allowed)
    end

    def validate_association(model, models_allowed)
      validate_model(model)

      fail CustomErrors::FilterArgumentError, "Models allowed must be an Array, got #{models_allowed}" unless models_allowed.is_a?(Array)
      fail CustomErrors::FilterArgumentError, "Model must be in #{models_allowed}, got #{model}" unless models_allowed.include?(model)
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

    def validate_node_or_attribute(value)
      check = value.is_a?(Arel::Nodes::Node) || value.is_a?(String) || value.is_a?(Arel::Attributes::Attribute)
      fail CustomErrors::FilterArgumentError, "Value must be Arel::Nodes::Node or String or Arel::Attributes::Attribute, got #{value}" unless check
    end

    # Validate name value.
    # @param [Symbol] name
    # @param [Array<Symbol>] allowed
    # @raise [FilterArgumentError] if name is not a symbol in allowed
    # @return [void]
    def validate_name(name, allowed)
      fail CustomErrors::FilterArgumentError, "Name must not be null, got #{name}" if name.blank?
      fail CustomErrors::FilterArgumentError, "Name must be a symbol, got #{name}" unless name.is_a?(Symbol)
      fail CustomErrors::FilterArgumentError, "Allowed must be an Array, got #{allowed}" unless allowed.is_a?(Array)
      fail CustomErrors::FilterArgumentError, "Name must be in #{allowed}, got #{name}" unless allowed.include?(name)
    end

    # Validate model value.
    # @param [ActiveRecord::Base] model
    # @raise [FilterArgumentError] if model is not an ActiveRecord::Base
    # @return [void]
    def validate_model(model)
      fail CustomErrors::FilterArgumentError, "Model must be an ActiveRecord::Base, got #{model.base_class}" unless model < ActiveRecord::Base
    end

    # Validate an array.
    # @param [Array, Arel::SelectManager] value
    # @raise [FilterArgumentError] if value is not a valid Array.
    # @return [void]
    def validate_array(value)
      fail CustomErrors::FilterArgumentError, "Value must not be null, got #{value}" if value.blank?
      fail CustomErrors::FilterArgumentError, "Value must be an Array or Arel::SelectManager, got #{value.class}" unless value.is_a?(Array) || value.is_a?(Arel::SelectManager)
    end

    # Validate array items. Do not validate if value is not an Array.
    # @param [Array] value
    # @raise [FilterArgumentError] if Array contents are not valid.
    # @return [void]
    def validate_array_items(value)
      # must be a collection of items
      if !value.respond_to?(:each) || !value.respond_to?(:all?) || !value.respond_to?(:any?) || !value.respond_to?(:count)
        fail CustomErrors::FilterArgumentError, "Must be a collection of items, got #{value.class}."
      end

      # if there are no items, let it through
      if value.count > 0
        # all items must be the same type. Assume the first item is the correct type.
        type_compare_item = value[0].class
        type_compare = value.all? { |item| item.is_a?(type_compare_item) }
        fail CustomErrors::FilterArgumentError, 'Array values must be a single consistent type.' unless type_compare

        # restrict length of strings
        if type_compare_item.is_a?(String)
          max_string_length = 120
          string_length = value.all? { |item| item.size <= max_string_length }
          fail CustomErrors::FilterArgumentError, "Array values that are strings must be #{max_string_length} characters or less." unless string_length
        end

        # array contents cannot be Arrays or Hashes
        array_check = value.any? { |item| item.is_a?(Array) }
        fail CustomErrors::FilterArgumentError, 'Array values cannot be arrays.' if array_check

        hash_check = value.any? { |item| item.is_a?(Hash) }
        fail CustomErrors::FilterArgumentError, 'Array values cannot be hashes.' if hash_check

      end
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

    # Check that a hash contains a key with expected type of value.
    # @param [Hash] hash
    # @param [Object] key
    # @param [Array<Object>, Object] value_types
    # @raise [FilterArgumentError] if hash does not contain expected key
    # @raise [FilterArgumentError] if hash key does not have expected type
    # @return [void]
    def validate_hash_key(hash, key, value_types)
      fail CustomErrors::FilterArgumentError, "Hash must include key #{key}." unless hash.include?(key)
      value_types_normalised = [value_types].flatten
      value = hash[key]
      is_class = value.class === Class
      is_valid = value_types_normalised.any? { |value_type| is_class ? value < value_type : value.is_a?(value_type) }
      fail CustomErrors::FilterArgumentError, "Hash key must be one of #{value_types_normalised}, got #{hash[key].class}." unless is_valid
    end

    def validate_closure(value, parameters = [])
      fail CustomErrors::FilterArgumentError, "Value must be a lambda or proc, got #{value.class}." unless value.is_a?(Proc)
      parameters_normalised = value.parameters.map(&:last).map(&:to_sym)
      fail CustomErrors::FilterArgumentError, "Lambda or proc must have parameters matching #{parameters}, got #{parameters_normalised}." unless parameters_normalised == parameters
    end

    # Validate the filter_settings for a model.
    def validate_filter_settings(value)
      validate_hash(value)

      # Common filter settings

      validate_array(value[:valid_fields])
      validate_array_items(value[:valid_fields])

      validate_array(value[:render_fields])
      validate_array_items(value[:render_fields])

      validate_array(value[:text_fields]) if value.include?(:text_fields)
      validate_array_items(value[:text_fields]) if value.include?(:text_fields)

      fail CustomErrors::FilterArgumentError, 'Controller name must be a symbol.' unless value[:controller].is_a?(Symbol)
      fail CustomErrors::FilterArgumentError, 'Action name must be a symbol.' unless value[:action].is_a?(Symbol)

      validate_hash(value[:defaults])

      fail CustomErrors::FilterArgumentError, 'Order by must be a symbol.' unless value[:defaults][:order_by].is_a?(Symbol)
      fail CustomErrors::FilterArgumentError, 'Direction must be a symbol.' unless value[:defaults][:direction].is_a?(Symbol)

      # advanced filter settings

      if value.include?(:field_mappings)
        validate_array(value[:field_mappings])

        # each field_mapping must be a hash with a :name and :value
        value[:field_mappings].each do |field_mapping_hash|
          validate_hash(field_mapping_hash)
          validate_hash_key(field_mapping_hash, :name, Symbol)
          validate_hash_key(field_mapping_hash, :value, Arel::Nodes::Node)
        end
      end

      validate_closure(value[:custom_fields], [:item, :user]) if value.include?(:custom_fields)
      validate_closure(value[:new_spec_fields], [:user]) if value.include?(:new_spec_fields)

      validate_hash_key(value, :base_association, ActiveRecord::Relation) if value.include?(:base_association)
      validate_hash_key(value, :base_association_key, Symbol) if value.include?(:base_association)
      validate_filter_associations(value[:valid_associations]) if value.include?(:valid_associations)

    end

    def validate_filter_associations(value)
      value.each do |association|
        validate_hash_key(association, :join, [ActiveRecord::Base, Arel::Table])
        validate_hash_key(association, :on, Arel::Nodes::Node)
        validate_hash_key(association, :available, [TrueClass, FalseClass])

        unless association[:associations].blank?
          validate_filter_associations(association[:associations])
        end
      end
    end

  end
end