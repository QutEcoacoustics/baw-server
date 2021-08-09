# frozen_string_literal: true

module Baw
  module Arel
    # Low-level helpers for manipulating Arel expressions.
    module Helpers
      module_function

      IS_AREL_NODE = ->(x) { ::Arel.arel_node?(x) }
      IS_AREL_NODES = ->(x) { x.is_a?(Array) ? x.all?(&IS_AREL_NODE) : IS_AREL_NODE.call(x) }

      def validate_column(model, column)
        table_column = model.columns_hash[column.to_s]
        if table_column.nil?
          raise ArgumentError, "Can't upsert column #{column} because it does not belong to the table #{table.name}"
        end

        model.arel_table[column.to_sym]
      end

      def upsert_on_conflict_sum(arel_table, *column_names)
        # `excluded` is the special postgres name for the row that was being inserted
        column_names.map { |column_name|
          ::Arel::Nodes::Assignment.new(
            make_on_conflict_column(arel_table, column_name),
            (make_qualified_column(arel_table, column_name) + upsert_excluded_column(arel_table, column_name))
          )
        }
      end

      def upsert_excluded_column(arel_table, column)
        column = arel_table[column] if column.is_a?(Symbol)
        Baw::Arel::Nodes::ExcludedColumn.new(column)
      end

      def make_on_conflict_column(arel_table, column)
        column = arel_table[column] if column.is_a?(Symbol)
        ::Arel::Nodes::UnqualifiedColumn.new(column)
      end

      def make_unqualified_column(arel_table, column)
        column = arel_table[column] if column.is_a?(Symbol)
        ::Arel::Nodes::UnqualifiedColumn.new(column)
      end

      def make_qualified_column(arel_table, column)
        column = arel_table[column] if column.is_a?(Symbol)
        column
      end

      def make_column_group(values)
        ::Arel::Nodes::Grouping.new(values)
      end

      def wrap_value(value)
        ::Arel::Nodes::SqlLiteral.new(value)
      end

      def wrap_columns(arel_table, values)
        transform = lambda { |value|
          case value
          when String
            ::Arel::Nodes::SqlLiteral.new(value)
          when Symbol
            column = arel_table[value]
            ::Arel::Nodes::UnqualifiedColumn.new(column)
          when IS_AREL_NODE
            value
          else
            raise "returning value type not supported: #{value}"
          end
        }

        return transform.call(values) unless values.is_a?(Enumerable)

        values.flatten.map(&transform)
      end

      def self.upsert_excluded_column(arel_table, column)
        column = arel_table[column] if column.is_a?(Symbol)
        Baw::Arel::Nodes::ExcludedColumn.new(column)
      end
    end
  end
end
