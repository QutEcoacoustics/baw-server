# frozen_string_literal: true

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
        raise CustomErrors::FilterArgumentError, 'Order by must not be null' if order_by.blank?
        raise CustomErrors::FilterArgumentError, 'Direction must not be null' if direction.blank?
        raise CustomErrors::FilterArgumentError, 'Valid Fields must not be null' if valid_fields.blank?

        direction_sym = direction.to_sym
        order_by_sym = order_by.to_sym
        valid_fields_sym = valid_fields.map(&:to_sym)

        unless valid_fields_sym.include?(order_by_sym)
          raise CustomErrors::FilterArgumentError, "Order by must be in #{valid_fields_sym}, got #{order_by_sym}"
        end
        unless [:desc, :asc].include?(direction_sym)
          raise CustomErrors::FilterArgumentError, "Direction must be asc or desc, got #{direction_sym}"
        end
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

    # Check that value is an integer between min and max.
    # @param [Integer] value
    # @param [Integer] min
    # @param [Integer] max
    # @return [void]
    def validate_integer(value, min = nil, max = nil)
      raise CustomErrors::FilterArgumentError, 'Value must not be blank' if value.blank?
      if value.blank? || value != value.to_i
        raise CustomErrors::FilterArgumentError, "Value must be an integer, got #{value}"
      end

      value_i = value.to_i

      if !min.blank? && value_i < min
        raise CustomErrors::FilterArgumentError, "Value must be #{min} or greater, got #{value_i}"
      end
      if !max.blank? && value_i > max
        raise CustomErrors::FilterArgumentError, "Value must be #{max} or less, got #{value_i}"
      end
    end

    # Check that value is a string.
    # @param [String] value
    # @return [void]
    def validate_string(value)
      raise CustomErrors::FilterArgumentError, 'Value must be a string' unless value.is_a?(String)
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

      unless models_allowed.is_a?(Array)
        raise CustomErrors::FilterArgumentError, "Models allowed must be an Array, got #{models_allowed}"
      end
      unless models_allowed.include?(model)
        raise CustomErrors::FilterArgumentError, "Model must be in #{models_allowed}, got #{model}"
      end
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
      unless table.is_a?(Arel::Table)
        raise CustomErrors::FilterArgumentError, "Table must be Arel::Table, got #{table.class}"
      end
    end

    # Validate table value.
    # @param [ActiveRecord::Relation] query
    # @raise [FilterArgumentError] if query is not an Arel::Query
    # @return [void]
    def validate_query(query)
      unless query.is_a?(ActiveRecord::Relation)
        raise CustomErrors::FilterArgumentError, "Query must be ActiveRecord::Relation, got #{query.class}"
      end
    end

    # Validate condition value.
    # @param [Arel::Nodes::Node] condition
    # @raise [FilterArgumentError] if condition is not an Arel::Nodes::Node
    # @return [void]
    def validate_condition(condition)
      if !condition.is_a?(Arel::Nodes::Node) && !condition.is_a?(String)
        raise CustomErrors::FilterArgumentError, "Condition must be Arel::Nodes::Node or String, got #{condition}"
      end
    end

    # Validate projection value.
    # @param [Arel::Attributes::Attribute] projection
    # @raise [FilterArgumentError] if projection is not an Arel::Attributes::Attribute
    # @return [void]
    def validate_projection(projection)
      if projection.is_a?(Hash)
        validate_hash_key(projection, :projection, [Arel::Nodes::Node, Arel::Attributes::Attribute])
        validate_hash_key(projection, :joins, Array)
        validate_table(projection[:base_table])
        projection[:joins].each do |join|
          validate_hash(join)
          validate_table(join[:arel_table])
          validate_hash_key(join, :type, Arel::Nodes::Join)
          validate_hash_key(join, :on, Arel::Nodes::Equality)
        end
        return
      end

      validate_node_or_attribute(projection)
    end

    def validate_node_or_attribute(value)
      check = value.is_a?(Arel::Nodes::Node) || value.is_a?(String) || value.is_a?(Arel::Attributes::Attribute)
      unless check
        raise CustomErrors::FilterArgumentError,
          "Value must be Arel::Nodes::Node or String or Arel::Attributes::Attribute, got #{value}"
      end
    end

    # Validate name value.
    # @param [Symbol] name
    # @param [Array<Symbol>] allowed
    # @raise [FilterArgumentError] if name is not a symbol in allowed
    # @return [void]
    def validate_name(name, allowed)
      raise CustomErrors::FilterArgumentError, "Name must not be null, got #{name}" if name.blank?
      raise CustomErrors::FilterArgumentError, "Name must be a symbol, got #{name}" unless name.is_a?(Symbol)
      raise CustomErrors::FilterArgumentError, "Allowed must be an Array, got #{allowed}" unless allowed.is_a?(Array)
      raise CustomErrors::FilterArgumentError, "Name must be in #{allowed}, got #{name}" unless allowed.include?(name)
    end

    # Validate model value.
    # @param [ActiveRecord::Base] model
    # @raise [FilterArgumentError] if model is not an ActiveRecord::Base
    # @return [void]
    def validate_model(model)
      unless model < ActiveRecord::Base
        raise CustomErrors::FilterArgumentError, "Model must be an ActiveRecord::Base, got #{model.base_class}"
      end
    end

    # Validate an array.
    # @param [Array, Arel::SelectManager] value
    # @raise [FilterArgumentError] if value is not a valid Array.
    # @return [void]
    def validate_array(value)
      raise CustomErrors::FilterArgumentError, "Value must not be null, got #{value}" if value.nil?
      unless value.is_a?(Array) || value.is_a?(Arel::SelectManager)
        raise CustomErrors::FilterArgumentError, "Value must be an Array or Arel::SelectManager, got #{value.class}"
      end
    end

    # Validate array items. Do not validate if value is not an Array.
    # @param [Array] value
    # @raise [FilterArgumentError] if Array contents are not valid.
    # @return [void]
    def validate_array_items(value)
      # must be a collection of items
      if !value.respond_to?(:each) || !value.respond_to?(:all?) || !value.respond_to?(:any?) || !value.respond_to?(:count)
        raise CustomErrors::FilterArgumentError, "Must be a collection of items, got #{value.class}."
      end

      # if there are no items, let it through
      if value.count.positive?
        # all items must be the same type. Assume the first item is the correct type.
        type_compare_item = value[0].class
        type_compare = value.all? { |item| item.is_a?(type_compare_item) }
        raise CustomErrors::FilterArgumentError, 'Array values must be a single consistent type.' unless type_compare

        # restrict length of strings
        if type_compare_item.is_a?(String)
          max_string_length = 120
          string_length = value.all? { |item| item.size <= max_string_length }
          unless string_length
            raise CustomErrors::FilterArgumentError,
              "Array values that are strings must be #{max_string_length} characters or less."
          end
        end

        # array contents cannot be Arrays or Hashes
        array_check = value.any? { |item| item.is_a?(Array) }
        raise CustomErrors::FilterArgumentError, 'Array values cannot be arrays.' if array_check

        hash_check = value.any? { |item| item.is_a?(Hash) }
        raise CustomErrors::FilterArgumentError, 'Array values cannot be hashes.' if hash_check

      end
    end

    # Validate a hash.
    # @param [Array] value
    # @raise [FilterArgumentError] if value is not a valid Hash.
    # @return [void]
    def validate_hash(value)
      raise CustomErrors::FilterArgumentError, "Value must not be null, got #{value}" if value.blank?
      raise CustomErrors::FilterArgumentError, "value must be a Hash, got #{value}" unless value.is_a?(Hash)
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
      raise CustomErrors::FilterArgumentError, 'Value for extract must not be null' if value.blank?
      unless valid.include?(value.downcase.to_sym)
        raise CustomErrors::FilterArgumentError, "Value for extract must be in #{valid}, got #{value}"
      end
    end

    # Escape wildcards in like value..
    # @param [String] value
    # @return [String] sanitized value
    def sanitize_like_value(value)
      value.gsub(/[\\_%|]/) { |x| "\\#{x}" }
    end

    # Escape meta-characters in SIMILAR TO value.
    # see http://www.postgresql.org/docs/9.3/static/functions-matching.html
    # @param [String] value
    # @return [String] sanitized value
    def sanitize_similar_to_value(value)
      value.gsub(/[\\_%|*+?{}()\[\]]/) { |x| "\\#{x}" }
    end

    # Remove all except 0-9, a-z, _ from projection alias
    # @param [String] value
    # @return [String] sanitized value
    def sanitize_projection_alias(value)
      value.gsub(/[^0-9a-zA-Z_]/) { |x| }
    end

    # Check that value is a float.
    # @param [Object] value
    # @raise [FilterArgumentError] if value is not a float
    # @return [void]
    def validate_float(value)
      raise CustomErrors::FilterArgumentError, 'Must have a value, got blank' if value.blank?

      filtered = value.to_s.tr('^0-9.', '')
      raise CustomErrors::FilterArgumentError, "Value must be a float, got #{filtered}" if filtered != value
      if filtered != value.to_f
        raise CustomErrors::FilterArgumentError, "Value must be a float after conversion, got #{filtered}"
      end

      value_f = filtered.to_f
      raise CustomErrors::FilterArgumentError, "Value must be greater than 0, got #{value_f}" if value_f <= 0
    end

    # Check that value is a 'basic class'.
    # @param [Object] value
    # @raise [FilterArgumentError] if value is not a 'basic class'
    # @return [void]
    def validate_basic_class(node, value)
      return if value.is_a?(NilClass) || value.is_a?(Integer) || value.is_a?(String) || value.is_a?(Float) ||
                value.is_a?(TrueClass) || value.is_a?(FalseClass)

      node_name = node.respond_to?(:name) ? node.name : '(custom item)'

      # allow treating a hash as a basic value if it serialized into json/jsonb
      # in the database
      if value.is_a?(Hash) && !json_column?(node)
        raise CustomErrors::FilterArgumentError,
          "The value for #{node_name} must not be a hash (unless its underlying type is a hash)"
      end

      raise CustomErrors::FilterArgumentError, "The value for #{node_name} must not be an array" if value.is_a?(Array)
      raise CustomErrors::FilterArgumentError, "The value for #{node_name} must not be a set" if value.is_a?(Set)
      raise CustomErrors::FilterArgumentError, "The value for #{node_name} must not be a range" if value.is_a?(Range)
    end

    # Check that a hash contains a key with expected type of value.
    # @param [Hash] hash
    # @param [Object] key
    # @param [Array<Object>, Object] value_types
    # @raise [FilterArgumentError] if hash does not contain expected key
    # @raise [FilterArgumentError] if hash key does not have expected type
    # @return [void]
    def validate_hash_key(hash, key, value_types)
      raise CustomErrors::FilterArgumentError, "Hash must include key #{key}." unless hash.include?(key)

      value_types_normalised = [value_types].flatten
      value = hash[key]
      is_class = value.class === Class
      is_valid = value_types_normalised.any? { |value_type| is_class ? value < value_type : value.is_a?(value_type) }
      unless is_valid
        raise CustomErrors::FilterArgumentError,
          "Hash key must be one of #{value_types_normalised}, got #{hash[key].class}."
      end
    end

    def validate_closure(value, parameters = [])
      unless value.is_a?(Proc)
        raise CustomErrors::FilterArgumentError, "Value must be a lambda or proc, got #{value.class}."
      end

      parameters_normalised = value
                              .parameters
                              .map(&:last)
                              .map { |name| name.to_s.ltrim('_').to_sym }
      unless parameters_normalised == parameters
        raise CustomErrors::FilterArgumentError,
          "Lambda or proc must have parameters matching #{parameters}, got #{parameters_normalised}."
      end
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

      unless value[:controller].is_a?(Symbol)
        raise CustomErrors::FilterArgumentError, 'Controller name must be a symbol.'
      end
      raise CustomErrors::FilterArgumentError, 'Action name must be a symbol.' unless value[:action].is_a?(Symbol)

      validate_hash(value[:defaults])

      unless value[:defaults][:order_by].is_a?(Symbol)
        raise CustomErrors::FilterArgumentError, 'Order by must be a symbol.'
      end
      unless value[:defaults][:direction].is_a?(Symbol)
        raise CustomErrors::FilterArgumentError, 'Direction must be a symbol.'
      end

      # advanced filter settings

      if value.include?(:field_mappings)
        validate_array(value[:field_mappings])

        # each field_mapping must be a hash with a :name and :value
        value[:field_mappings].each do |field_mapping_hash|
          validate_hash(field_mapping_hash)
          validate_hash_key(field_mapping_hash, :name, Symbol)
          validate_hash_key(field_mapping_hash, :value, [Arel::Nodes::Node, String])
        end
      end

      validate_closure(value[:custom_fields], [:item, :user]) if value.include?(:custom_fields)

      if value.include?(:custom_fields2)
        validate_hash(value[:custom_fields2])
        value[:custom_fields2].each_value do |custom_definition|
          validate_hash(custom_definition)
          validate_array(custom_definition[:query_attributes])
          validate_closure(custom_definition[:transform], [:item])
        end
      end

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

        validate_filter_associations(association[:associations]) unless association[:associations].blank?
      end
    end
  end
end
