# frozen_string_literal: true

module Baw
  module Arel
    # Low-level Arel node extensions used to construct a query abstract syntax tree.
    # Nodes in this class are used for upsert syntax expressions and other things.
    module Nodes
      class UpsertStatement < ::Arel::Nodes::Node
        include Comparable

        attr_accessor :insert, :on_conflict, :returning, :relation
      end

      class Returning < ::Arel::Nodes::Node
        include Comparable

        attr_accessor :expression
      end

      class OnConflict < ::Arel::Nodes::Node
        include Comparable

        attr_accessor :target, :where, :action
      end

      class OnConflictAction < ::Arel::Nodes::Node
      end

      class DoUpdateSetValues < OnConflictAction
        include Comparable
        attr_accessor :values, :where
      end

      class DoUpdateSetExpression < OnConflictAction
        include Comparable
        attr_accessor :expression
      end

      class ExcludedColumn < ::Arel::Nodes::UnqualifiedColumn
      end

      class DoNothing < OnConflictAction
      end

      # Allows casting a timestamp to a particular UTC offset (either with a timezone or offset)
      class AsTimeZone < ::Arel::Nodes::Function
        RETURN_TYPE = :datetime
        def initialize(left, right)
          right = ::Arel::Nodes::Quoted.new(right) if right.is_a?(String)
          super([left, ::Arel.sql('AT TIME ZONE'), right])
        end
      end

      class ArrayAgg < ::Arel::Nodes::NamedFunction
        def initialize(expr)
          super('array_agg', expr)
        end
      end

      class ArrayToJson < ::Arel::Nodes::NamedFunction
        def initialize(expr)
          super('array_to_json', expr)
        end
      end

      class Unnest < ::Arel::Nodes::NamedFunction
        def initialize(expr)
          super('unnest', expr)
        end
      end

      class ArrayConstructor < ::Arel::Nodes::Node
        include ::Arel::AliasPredication
        include ArrayFunctions

        attr_reader :expression

        def initialize(expressions)
          super()
          @expression = expressions
        end
      end

      class ArrayLike < ::Arel::Nodes::Node
        include ArrayFunctions
        include ::Arel::OrderPredications

        attr_reader :expression

        def initialize(expression)
          super()
          @expression = expression
        end
      end

      class Subscript < ArrayLike
        attr_reader :subscript_start, :subscript_end

        def initialize(array, subscript_start, subscript_end = :empty)
          super(array)

          case subscript_start
          in nil
            nil
          in Integer => s
            s + 1
          else
            raise ArgumentError, 'subscript_start must be an Integer or nil'
          end => subscript_start

          case subscript_end
          in :empty
            # when empty we make end==start to have an effect range of 1
            subscript_start
          in nil
            nil
          in Integer => e
            e + 1
          else
            raise ArgumentError, 'subscript_end must be an Integer, nil, or :empty'
          end => subscript_end

          @subscript_start = subscript_start
          @subscript_end = subscript_end
        end
      end
    end
  end
end
