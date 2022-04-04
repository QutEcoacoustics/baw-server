# frozen_string_literal: true

module Filter
  # Methods for creating custom fields on responses objects,
  # either virtual fields (constructed by Rails after querying)
  # or calculated fields (constructed by injecting more sql into the query  )
  module CustomField
    # Get the type of this custom field, either :calculated or :virtual
    # @param [Symbol] column_name - the name of the custom field (it's not really a column)
    # @return [Symbol, nil] nil if the field cannot be found, or the appropriate symbol
    def custom_field_type(column_name)
      return unless @custom_fields2.key?(column_name)

      @custom_fields2[column_name] => {arel:, query_attributes:}
      if !arel.nil?
        :calculated
      elsif !query_attributes.blank?
        :virtual
      else
        raise "Bad custom_field2 definition for #{column_name}"
      end
    end

    # Use a custom field 2 definition in a filter query (for filtering or projection of a calculated column)
    # @param [Symbol] column_name - the name of the custom field (it's not really a column)
    # @return [Hash, nil] a hash with the columns stated type and an arel expression to use in a filter.
    #   If no such column exists, will return nil.
    def build_custom_calculated_field(column_name)
      return unless @custom_fields2.key?(column_name)

      @custom_fields2[column_name] => {arel:, type:}

      if arel.nil?
        raise CustomErrors::FilterArgumentError,
          "Custom field #{column_name} is not supported for filtering or ordering"
      end
      raise NotImplementedError, "Custom field #{column_name} does not specify it's type" if type.nil?

      { type:, arel: }
    end

    # Use a custom field 2 definition in a filter query (for projection of a virtual column)
    # @param [Symbol] column_name - the name of the custom field (it's not really a column)
    # @return [Array<::Arel::Attributes::Attribute>, nil] a hash with the columns stated type and an arel expression to use in a filter.
    #   If no such column exists, will return nil.
    def build_custom_virtual_field(column_name)
      return unless @custom_fields2.key?(column_name)

      @custom_fields2[column_name] => {query_attributes:}

      raise "query_attributes cannot be empty for #{column_name}" if query_attributes.blank?

      query_attributes.map do |hint|
        # implicitly allow the hint here - the hint is
        # provided by filter settings and not user so
        # we assume it is secure
        validate_table_column(@table, hint, [hint])
        @table[hint]
      end
    end
  end
end
