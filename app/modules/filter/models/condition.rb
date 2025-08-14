# frozen_string_literal: true

module Filter
  module Models
    # Represents a condition to be applied to a query.
    # It contains the condition itself, any joins that need to be applied,
    # and any transforms that need to be applied to the query.
    Condition = Data.define(:predicate, :joins, :transforms) {
      def initialize(predicate:, joins: [], transforms: [])
        raise ArgumentError, 'predicate must be a Node' unless predicate.is_a?(::Arel::Nodes::Node)
        raise ArgumentError, 'joins must be an Array' unless joins.is_a?(Array)
        raise ArgumentError, 'join is not a Join' unless joins.all? { |join| join.is_a?(Arel::Nodes::Join) }
        raise ArgumentError, 'transforms must be an Array' unless transforms.is_a?(Array)
        raise ArgumentError, 'transform is not a Proc' unless transforms.all? { |transform| transform.is_a?(Proc) }

        super
      end

      def self.simple(predicate)
        new(predicate:, joins: [], transforms: [])
      end

      # Reduce a list of conditions into a single condition.
      # @param conditions [Array<Condition>] the conditions to reduce
      # @param block [Proc] a block that takes two predicates and combines them
      # @return [Condition] a new Condition with the combined predicate, joins, and transforms
      def self.reduce(conditions)
        transforms = []
        joins = []
        combined_predicate = conditions.reduce(nil) { |accumulator, condition|
          raise ArgumentError, 'condition must be a Condition' unless condition.is_a?(Condition)

          transforms.concat(condition.transforms)
          joins.concat(condition.joins)

          if accumulator.nil?
            condition.predicate
          else
            yield accumulator, condition.predicate
          end
        }

        new(predicate: combined_predicate, joins:, transforms:)
      end

      def self.apply_to_select_manager(select_manager, conditions)
        raise ArgumentError, 'select_manager must be a SelectManager' unless select_manager.is_a?(Arel::SelectManager)
        raise ArgumentError, 'conditions must be an Array' unless conditions.is_a?(Array)

        conditions.each do |condition|
          raise ArgumentError, 'condition must be a Condition' unless condition.is_a?(Condition)

          select_manager.join_sources.push(*condition.joins)

          condition.transforms.reduce(select_manager) do |current_query, transform|
            transform.call(current_query)
          end => select_manager

          select_manager.where(condition.predicate)
        end

        select_manager
      end

      # Merge this condition with another condition.
      # @param [Condition] other
      # @param [Proc] block a block that takes two predicates and combines them
      # @return [Condition] a new Condition with the combined predicate, joins, and transforms
      def merge(other)
        raise ArgumentError, 'other must be a Condition' unless other.is_a?(Condition)

        combined_predicate = yield predicate, other.predicate

        new(
          predicate: combined_predicate,
          joins: joins + other.joins,
          transforms: transforms + other.transforms
        )
      end

      # Map the predicate of this condition using a block.
      # @param [Proc] block a block that takes the current predicate and returns a new predicate
      # @return [Condition] a new Condition with the mapped predicate, and the same joins and transforms
      def map_predicate(&block)
        new_predicate = block.call(predicate)
        Condition.new(
          predicate: new_predicate,
          joins: joins,
          transforms: transforms
        )
      end
    }
  end
end
