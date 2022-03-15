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
    end
  end
end
