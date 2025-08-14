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

          maybe_visit o.target, collector

          collect_nodes_for o.where, collector, ' WHERE ', ' AND ' if o.where
          maybe_visit o.action, collector
        end

        def visit_Baw_Arel_Nodes_DoNothing(_o, collector)
          collector << 'DO NOTHING'
        end

        def visit_Baw_Arel_Nodes_DoUpdateSetValues(o, collector)
          collector << 'DO UPDATE '
          if o.values.present?
            collector << 'SET '
            collector = inject_join o.values, collector, ', '
          end

          collect_nodes_for o.where, collector, ' WHERE ', ' AND ' unless o.where.nil?

          collector
        end

        def visit_Baw_Arel_Nodes_DoUpdateSetExpression(o, collector)
          collector << 'DO UPDATE '
          if o.expression.present?
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

        def visit_Baw_Arel_Nodes_NamedArgument(o, collector)
          collector << o.name
          collector << ' => '
          visit(o.value, collector)
        end

        def visit_Baw_Arel_Nodes_AsTimeZone(o, collector)
          collector << '('
          collector = inject_join o.expressions, collector, ' '
          collector << ')'
          collector
        end

        def visit_Baw_Arel_Nodes_ArrayLike(o, collector)
          # essentially a noop, used only for injecting array like methods into
          # the AST
          visit o.expression, collector
        end

        def visit_Baw_Arel_Nodes_ArrayConstructor(o, collector)
          # wrapping in brackets
          collector << '(ARRAY['
          collector = inject_join o.expression, collector, ', '
          collector << '])'
        end

        def visit_Baw_Arel_Nodes_Subscript(o, collector)
          collector = visit o.expression, collector
          collector << '['

          # 4 cases:
          # 1. get one item 1=1
          # 2. get a bounded range of items 1:2
          # 3/4. get unbounded range of items 1: or :2

          case [o.subscript_start, o.subscript_end]
          in Integer => a, Integer => b if a == b
            collector = visit o.subscript_start, collector
          in nil, Integer
            collector << ':'
            collector = visit o.subscript_end, collector
          in Integer, nil
            collector = visit o.subscript_start, collector
            collector << ':'
          else
            collector = visit o.subscript_start, collector
            collector << ':'
            collector = visit o.subscript_end, collector
          end

          collector << ']'
          collector
        end
      end
      # rubocop:enable Naming/MethodName, Naming/MethodParameterName
    end
  end
end
