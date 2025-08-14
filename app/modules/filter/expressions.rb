# frozen_string_literal: true

module Filter
  # Allows for the parsing of functions to transform values in filter queries
  module Expressions
    KNOWN_EXPRESSIONS = {
      local_tz: LocalTimezone.new,
      local_offset: LocalOffsetTimezone.new,
      time_of_day: TimeOfDay.new
    }.freeze

    def expression?(value)
      return false unless value.is_a?(Hash)

      has_expressions = value.key?(:expressions)
      has_value = value.key?(:value)

      case [has_expressions, has_value]
      when [true, true]
        true
      when [false, false]
        false
      when [true, false]
        raise CustomErrors::FilterArgumentError, 'Expression must contain a value'
      when [false, true]
        raise CustomErrors::FilterArgumentError, 'Expressions object must contain an expressions array'
      end
    end

    # Chains together several expressions that might be applied to a condition
    # enhancing both the field (left) and value (right) parts of the condition.
    # Will also return a series of transforms that need to be applied to the whole query.
    # @return [[Array<Proc>, ::Arel::Nodes::Node, ::Arel::Nodes::Node]] a tuple of the modified query, field, and value
    def compose_expression(expression_object, model:, column_name:, column_node:, column_type:)
      expression_object => { expressions:, value: raw_value }

      raise "column_type not supplied (it was #{column_type})" unless column_type.is_a?(Symbol)
      unless column_node.is_a?(::Arel::Nodes::Node) || column_node.is_a?(::Arel::Attributes::Attribute)
        raise "column was not an Arel::Nodes::Node, it was a #{column_node.class}"
      end

      last_type = column_type
      query_transforms = []

      field = column_node

      validate_basic_class(field, raw_value)
      case raw_value
      when String
        ::Arel::Nodes::Quoted.new(raw_value)
      else
        raw_value
      end => value

      raise CustomErrors::FilterArgumentError, 'Expressions must contain at least one function' if expressions.blank?

      # apply each expression in sequence, building up the query
      expressions.each_with_index do |name, index|
        expression = KNOWN_EXPRESSIONS.fetch(name.to_sym, nil)

        raise CustomErrors::FilterArgumentError, "Expression function `#{name}` does not exist" if expression.nil?

        context = {
          last: index == (expressions.length - 1),
          raw_value:
        }

        expression.validate_type(last_type, model, column_name)

        field = expression.transform_field(field, model, column_name)
        value = expression.transform_value(value, model, column_name, context)

        query_transform = expression.transform_query(model, column_name)
        validate_closure(query_transform, [:query])
        query_transforms << query_transform

        last_type = expression.new_type
      end

      [query_transforms, field, value, last_type]
    end
  end
end
