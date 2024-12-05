# frozen_string_literal: true

module Baw
  module ActiveRecord
    # Helper methods for incrementing counters
    module Upsert
      # Increments the counters from attributes by inserting the values or
      # updating existing values to be the sum of the new and old values.
      # Primary keys are detected and omitted on update.
      # Does not construct a model, does not return a value.
      # @param [Hash] attributes a hash of attributes to upsert
      # @return [void]
      def upsert_counter(attributes)
        pks = _primary_keys

        update_attrs = attributes.keys.reject { |key| pks.include?(key.to_s) }
        upsert_query(
          attributes,
          returning: nil,
          on_conflict: Baw::Arel::Helpers.upsert_on_conflict_sum(arel_table, *update_attrs)
        ).execute
      end

      # Creates an upsert query for one row of data.
      # Rails has an upsert query, but it does not support custom sql on conflict. It
      # won't until Rails 7, and it is not viable to upgrade just ActiveRecord.
      # @param [Hash] attributes a hash of attributes to upsert
      # @param [Symbol,Array<::Arel::Nodes::node>,::Arel::Nodes::Node] on_conflict:
      #   What to do when the insert fails.
      #   - :do_nothing simply cancels the insert.
      #   - :update generates a list of updates for columns that are not primary keys.
      #   You can pass an array of ::Arel::Nodes here (or Arel.Sql() literals) to
      #   do a custom update. Custom updates are useful for combining new and old values
      #   (e.g. incrementing counters with a SUM) or for inserting computed values.
      # @param [Symbol,Array<Symbol>,String] conflict_target: used to constrain
      #   the conflict resolution to a subset of columns. If omitted (or if the symbol
      #   `:primary_keys` is passed), it defaults to the value of `model.primary_keys`.
      #   If set to `nil` not specified and leaves it up to the database.
      #   If a symbol or an array of symbols it assumed these
      #   are references to a tuple of columns that are unique. If a string, is used
      #   as the name of the unique constraint to reference for uniqueness.
      # @param [Array<::Arel::Nodes::Node>] conflict_where: a predicate used to allow partial
      #   unique indexes to be resolved.
      # @return [Baw::Arel::UpsertManager]
      def upsert_query(
        attributes,
        on_conflict:,
        returning: [],
        conflict_target: :primary_keys,
        conflict_where: nil
      )
        Baw::Arel::UpsertManager.new(self).tap do |u|
          u.insert(attributes)

          u.on_conflict(on_conflict, conflict_target, conflict_where)

          returning = _primary_keys if !returning.nil? && returning.empty?
          u.returning(returning)
        end
      end

      private

      def _primary_keys
        primary_key.is_a?(Array) ? primary_key : [primary_key]
      end
    end
  end
end
