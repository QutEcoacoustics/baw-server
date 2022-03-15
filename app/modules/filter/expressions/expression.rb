# frozen_string_literal: true

module Filter
  module Expressions
    # An expression node that can be used to transform a field in a query
    class Expression
      # rubocop:disable Lint/UnusedMethodArgument

      # Validates that the input type of the field the expression is applied to is supported
      # @param [Symbol] type - the type of the preceding expression
      # @param [::ActiveRecord::Base] model
      # @param [Symbol] column
      # @return nil
      def validate_type(type, model, column_name)
        raise NotImplementedError, 'You must implement this method'
      end

      # @param [::Arel::Nodes::Node] node
      # @param [::ActiveRecord::Base] model
      # @param [Symbol] column
      # @return [::Arel::Nodes::Node]
      def transform_value(node, model, column_name, context)
        raise NotImplementedError, 'You must implement this method'
      end

      # @param [::Arel::Nodes::Node] node
      # @param [::ActiveRecord::Base] model
      # @param [Symbol] column
      # @return [::Arel::Nodes::Node]
      def transform_field(node, model, column_name)
        raise NotImplementedError, 'You must implement this method'
      end

      # @return [Symbol]
      def new_type
        raise NotImplementedError, 'You must implement this method'
      end

      # Transform the query.
      # Must return a lambda to be used at a later stage.
      def transform_query(model, column_name)
        # default: do nothing
        ->(query) { query }
      end

      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
