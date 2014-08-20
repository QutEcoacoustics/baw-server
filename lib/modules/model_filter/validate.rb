require 'active_support/concern'

# Provides common functionality for composing queries.
module ModelFilter
  module Validate
    extend ActiveSupport::Concern

    # using Arel https://github.com/rails/arel
    # http://robots.thoughtbot.com/using-arel-to-compose-sql-queries

    module ClassMethods

      # Validate query, table, and column values.
      # @param [Arel::Query] query
      # @param [Arel::Table] table
      # @param [Symbol] column_name
      # @param [Array<Symbol>] allowed
      def validate_query_table_column(query, table, column_name, allowed)
        validate_query(query)
        validate_table(table)
        validate_column_name(column_name, allowed)
      end

      # Validate table and column values.
      # @param [Arel::Table] table
      # @param [Symbol] column_name
      # @param [Array<Symbol>] allowed
      def validate_table_column(table, column_name, allowed)
        validate_table(table)
        validate_column_name(column_name, allowed)
      end

      # Validate table value.
      # @param [Arel::Table] table
      # @raise [ArgumentError] if table is not an Arel::Table
      def validate_table(table)
        fail ArgumentError, "Table must be Arel::Table, got #{query.inspect}" unless table.is_a?(Arel::Table)
      end

      # Validate table value.
      # @param [ActiveRecord::Relation] query
      # @raise [ArgumentError] if query is not an Arel::Query
      def validate_query(query)
        fail ArgumentError, "Query must be ActiveRecord::Relation, got #{query.inspect}" unless query.is_a?(ActiveRecord::Relation)
      end

      # Validate condition value.
      # @param [Arel::Nodes::Node] condition
      # @raise [ArgumentError] if condition is not an Arel::Nodes::Node
      def validate_condition(condition)
        fail ArgumentError, "Condition must be Arel::Nodes::Node, got #{condition.inspect}" unless condition.is_a?(Arel::Nodes::Node)
      end

      # Validate column name value.
      # @param [Symbol] column_name
      # @param [Array<Symbol>] allowed
      # @raise [ArgumentError] if column name is not a symbol in allowed
      def validate_column_name(column_name, allowed)
        fail ArgumentError, "Column name must be a symbol, got #{column_name.inspect}" unless column_name.is_a?(Symbol)
        fail ArgumentError, "Allowed must be an Array, got #{allowed.inspect}" unless allowed.is_a?(Array)
        fail ArgumentError, "Column name must be in #{allowed.inspect}, got #{column_name.inspect}" unless allowed.include?(column_name)
      end

      # Validate model value.
      # @param [ActiveRecord::Base] model
      # @raise [ArgumentError] if model is not an ActiveRecord::Base
      def validate_model(model)
        fail ArgumentError, "Model must respond to scoped, got #{model.inspect}" unless model.respond_to?(:scoped)
      end

      # Escape wildcards in like value..
      # @param [String] value
      # @raise [String] escaped like value
      def sanitize_like_value(value)
        value.gsub(/[\\_%\|]/) { |x| "\\#{x}" }
      end

    end
  end
end