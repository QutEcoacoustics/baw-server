# frozen_string_literal: true

module Baw
  module Arel
    module Visitors
      # Names of methods have to follow the convention of `visit_<ClassName>`
      # rubocop:disable Naming/MethodName, Naming/MethodParameterName

      # Converts Baw::Arel::Nodes instances in an AST into SQL using the visitor pattern.
      # An extension to https://github.com/rails/rails/blob/main/activerecord/lib/arel/visitors/to_sql.rb.
      # Only valid for postgesql.
      module ToSqlExtensions
        def visit_Baw_Arel_Nodes_UpsertStatement(o, collector)
          # generate the insert first
          visit o.insert, collector

          maybe_visit o.on_conflict, collector

          maybe_visit o.returning, collector

          collector
        end

        def visit_Baw_Arel_Nodes_OnConflict(o, collector)
          collector << 'ON CONFLICT '

          visit o.target, collector

          collect_nodes_for o.where, collector, ' WHERE ', ' AND ' if o.where
          maybe_visit o.action, collector
        end

        def visit_Baw_Arel_Nodes_DoNothing(_o, collector)
          collector << 'DO NOTHING'
        end

        def visit_Baw_Arel_Nodes_DoUpdateSetValues(o, collector)
          collector << 'DO UPDATE '
          unless o.values.blank?
            collector << 'SET '
            collector = inject_join o.values, collector, ', '
          end

          collect_nodes_for o.where, collector, ' WHERE ', ' AND ' unless o.where.nil?

          collector
        end

        def visit_Baw_Arel_Nodes_DoUpdateSetExpression(o, collector)
          collector << 'DO UPDATE '
          unless o.expression.blank?
            collector << 'SET '
            visit o.expression, collector
          end

          collector
        end

        def visit_Baw_Arel_Nodes_ExcludedColumn(o, collector)
          collector << "EXCLUDED.#{quote_column_name(o.name)}"
          collector
        end

        def visit_Baw_Arel_Nodes_Returning(o, collector)
          collector << ' RETURNING '

          visit o.expression, collector
        end

        def visit_Baw_Arel_Nodes_AsTimeZone(o, collector)
          collector << '('
          o.expressions.each_with_index do |e, i|
            collector << ' ' if i != 0
            collector = visit e, collector
          end
          collector << ')'
          collector
        end
      end

      # rubocop:enable Naming/MethodName, Naming/MethodParameterName
    end
  end
end
