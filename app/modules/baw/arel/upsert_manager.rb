# frozen_string_literal: true

module Baw
  module Arel
    # Manages the Arel composition for an upsert query.
    class UpsertManager < ::Arel::TreeManager
      include Helpers

      attr_reader :model

      def initialize(model)
        super()
        @ast = Nodes::UpsertStatement.new
        @ast.relation = model.arel_table
        @model = model
      end

      def table
        @table ||= model.arel_table
      end

      def primary_keys
        @primary_keys ||= model.primary_keys
      end

      def insert(attributes)
        @ast.insert = ::Arel::Nodes::InsertStatement.new.tap do |i|
          i.relation = table
          i.columns = attributes.keys.map { |key| validate_column(model, key) }
          i.values = ::Arel::Nodes::ValuesList.new([
            attributes.map { |_key, value| ::Arel::Nodes::BindParam.new(value) }
          ])
        end
      end

      def on_conflict(on_conflict, conflict_target, conflict_where)
        @ast.on_conflict = Nodes::OnConflict.new.tap do |c|
          c.action = make_conflict_action(on_conflict)

          c.target = if conflict_target.is_a?(String)
                       wrap_value(conflict_target)
                     else
                       make_column_group(wrap_columns(table, conflict_target || primary_keys))
                     end

          unless ::Arel.arel_node?(conflict_where) || conflict_where.nil?
            raise ArgumentError, "`conflict_where` must be an arel expression but was #{conflict_where}"
          end

          c.where = Array(conflict_where)
        end
      end

      def returning(returning)
        return if returning.nil?

        @ast.returning = Nodes::Returning.new
        @ast.returning.expression = wrap_columns(table, returning)
      end

      def execute
        sql, binds = model.connection.send(:to_sql_and_binds, self)
        result = model.connection.exec_query(sql, "#{model.name} upsert", binds)

        return nil if @ast.returning.nil?

        result.cast_values
      end

      private

      def column_is_pk(column)
        primary_keys.include?(column.name)
      end

      def make_conflict_action(on_conflict)
        case on_conflict
        when :update
          Baw::Arel::Nodes::DoUpdateSetValues.new.tap do |u|
            u.values = @ast.insert.columns.reject(&method(:column_is_pk)).map { |column|
              ::Arel::Nodes::Assignment.new(
                ::Arel::Nodes::UnqualifiedColumn.new(column),
                Helpers.upsert_excluded_column(table, column)
              )
            }
          end
        when :do_nothing
          Baw::Arel::Nodes::DoNothing.new
        when IS_AREL_NODES
          Baw::Arel::Nodes::DoUpdateSetExpression.new.tap do |u|
            u.expression = on_conflict
          end
        else
          raise "unknown on_conflict action #{on_conflict}"
        end
      end
    end
  end
end
