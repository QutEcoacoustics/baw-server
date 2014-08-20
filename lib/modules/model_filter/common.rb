# Provides grouping, sorting, paging, 'and', and 'or' for composing queries.
module ModelFilter
  class Common
    include Validate

    class << self

      public

      # Get the ActiveRecord::Relation that represents zero records.
      # @param [ActiveRecord::Base] model
      # @return [ActiveRecord::Relation] query that will get zero records
      def none_relation(model)
        validate_model(model)
        model.where('1 = 0')
      end

      # Get the ActiveRecord::Relation that represents all records.
      # @param [ActiveRecord::Base] model
      # @return [ActiveRecord::Relation] query that will get all records
      def all_relation(model)
        validate_model(model)
        model.scoped
      end

      # Get the Arel::Table for this model.
      # @param [ActiveRecord::Base] model
      # @return [Arel::Table] arel table
      def table(model)
        validate_model(model)
        model.arel_table
      end

      # Append sorting to a query.
      # @param [ActiveRecord::Relation] query
      # @param [Arel::Table] table
      # @param [Symbol] column_name
      # @param [Array<Symbol>] allowed
      # @param [Symbol] order
      # @return [ActiveRecord::Relation] the modified query
      def compose_sort(query, table, column_name, allowed, order)
        validate_query_table_column(query, table, column_name, allowed)
        fail ArgumentError, 'Order must not be null' if order.blank?
        order = order.to_sym

        if order == :asc
          query.order(table[column_name].asc)
        elsif order == :desc
          query.order(table[column_name].desc)
        else
          fail ArgumentError, "Order must be ':asc' or ':desc', got #{order.inspect}"
        end
      end

      # Append paging to a query.
      # @param [ActiveRecord::Relation] query
      # @param [Integer] offset
      # @param [Integer] limit
      # @return [ActiveRecord::Relation] the modified query
      def compose_paging(query, offset, limit)
        fail ArgumentError, 'Offset cannot be empty.' if offset.blank?
        fail ArgumentError, 'Limit cannot be empty.' if limit.blank?
        offset_i = offset.to_i
        limit_i = limit.to_i
        fail ArgumentError, "Offset must be an integer, got #{offset.inspect}" if offset_i.blank? || offset != offset_i
        fail ArgumentError, "Limit must be an integer, got #{limit.inspect}" if limit_i.blank? || limit != limit_i
        query.skip(offset).take(limit)
      end

      # Join conditions using or.
      # @param [Arel::Nodes::Node] first_condition
      # @param [Arel::Nodes::Node] second_condition
      # @return [Arel::Nodes::Node] condition
      def compose_or(first_condition, second_condition)
        validate_condition(first_condition)
        validate_condition(second_condition)
        first_condition.or(second_condition)
      end

      # Join conditions using and.
      # @param [Arel::Nodes::Node] first_condition
      # @param [Arel::Nodes::Node] second_condition
      # @return [Arel::Nodes::Node] condition
      def compose_and(first_condition, second_condition)
        validate_condition(first_condition)
        validate_condition(second_condition)
        first_condition.and(second_condition)
      end

      # Join conditions using not.
      # @param [Arel::Nodes::Node] condition
      # @return [Arel::Nodes::Node] condition
      def compose_not(condition)
        validate_condition(first_condition)
        validate_condition(second_condition)
        condition.not
      end
    end
  end
end