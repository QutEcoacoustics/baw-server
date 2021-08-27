# frozen_string_literal: true

module Baw
  module Arel
    # Low-level Arel node extensions used to construct a query abstract syntax tree.
    # Nodes in this class are used for upsert syntax expression.
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
    end
  end
end
