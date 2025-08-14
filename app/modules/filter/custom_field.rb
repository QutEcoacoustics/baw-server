# frozen_string_literal: true

module Filter
  # Methods for creating custom fields on responses objects,
  # either virtual fields (constructed by Rails after querying)
  # or calculated fields (constructed by injecting more sql into the query  )
  module CustomField
    module_function

    # Check if a custom field is defined in the custom_fields2 hash
    # @param [Symbol] column_name - the name of the custom field (it's not really a column)
    # @param [Hash] custom_fields2 - the custom fields definitions, defaults to @custom_fields2
    # @return [Boolean] true if the field is defined, false otherwise
    # @raises [RuntimeError] if the field is not defined correctly
    def custom_field_defined?(column_name, custom_fields2 = @custom_fields2)
      return false unless custom_fields2.key?(column_name)

      custom_fields2[column_name] => { arel:, query_attributes: }

      raise "Bad custom_field2 definition for `#{column_name}`" if arel.nil? && query_attributes.blank?

      true
    end

    # Check if a custom field is a calculated field
    # @param column_name [Symbol] - the name of the custom field
    # @param custom_fields2 [Hash] - the custom fields definitions, defaults to @custom_fields2
    # @return [Boolean] true if the field is a calculated field, false otherwise
    def custom_field_is_calculated?(column_name, custom_fields2 = @custom_fields2)
      custom_fields2.fetch(column_name, nil)&.[](:arel).present?
    end

    # Check if a custom field is a virtual field
    # @param column_name [Symbol] - the name of the custom field
    # @param custom_fields2 [Hash] - the custom fields definitions, defaults to @custom_fields2
    # @return [Boolean] true if the field is a virtual field, false otherwise
    def custom_field_is_virtual?(column_name, custom_fields2 = @custom_fields2)
      custom_fields2.fetch(column_name, nil)&.[](:query_attributes).present?
    end

    # Use a custom field 2 definition in a filter query (for filtering or projection of a calculated column)
    # @param [Symbol] column_name - the name of the custom field (it's not really a column)
    # @param [Hash] custom_fields2 - the custom fields definitions, defaults to @custom_fields2
    # @return [Hash, nil] a hash with the columns stated type and an arel expression to use in a filter.
    #   If no such column exists, will return nil.
    def build_custom_calculated_field(column_name, custom_fields2 = @custom_fields2)
      return unless custom_field_is_calculated?(column_name, custom_fields2)

      custom_fields2[column_name] => { arel:, type: }

      if arel.nil?
        raise CustomErrors::FilterArgumentError,
          "Custom field `#{column_name}` is not supported for filtering or ordering"
      end
      raise NotImplementedError, "Custom field `#{column_name}` does not specify it's type" if type.nil?

      joins = custom_fields2[column_name][:joins] || []

      { type:, arel:, joins: }
    end

    # Use a custom field 2 definition in a filter query (for projection of a virtual column)
    # @param [Symbol] column_name - the name of the custom field (it's not really a column)
    # @param [Hash] custom_fields2 - the custom fields definitions, defaults to @custom_fields2
    # @param [Arel::Table] table - the table to use for the query
    # @return [Array<::Arel::Attributes::Attribute>, nil] a hash with the columns stated type and an arel expression to use in a filter.
    #   If no such column exists, will return nil.
    def build_custom_virtual_field(column_name, custom_fields2 = @custom_fields2, table = @table)
      return unless custom_field_is_virtual?(column_name, custom_fields2)

      custom_fields2[column_name] => { query_attributes: }

      raise "query_attributes cannot be empty for `#{column_name}`" if query_attributes.blank?

      query_attributes.map do |hint|
        # implicitly allow the hint here - the hint is
        # provided by filter settings and not user so
        # we assume it is secure
        validate_table_column(table, hint, [hint])
        table[hint]
      end
    end
  end
end
