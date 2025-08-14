# frozen_string_literal: true

module Discardable
  AdditionalDiscard = Data.define(:reflections, :batch)
  # Handles soft deletes of records.
  #
  # Options:
  #
  # - :discard_column - The columns used to track soft delete, defaults to `:deleted_at`.
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :discard_column
      class_attribute :discarder_id_column
      class_attribute :discarder_user
      class_attribute :additional_discard_associations

      self.discard_column = :deleted_at
      self.discarder_id_column = :deleter_id
      self.discarder_user = -> { Current.user }
      self.additional_discard_associations ||= []

      # check the model has the column
      raise MissingDiscardColumn.new(self, discard_column) unless column_names.include?(discard_column.to_s)
      raise MissingDiscardColumn.new(self, discarder_id_column) unless column_names.include?(discarder_id_column.to_s)
      raise ArgumentError, 'discarder_user must be a Proc' unless discarder_user.is_a?(Proc)

      scope :kept, -> { unscope(where: discard_column).undiscarded }
      scope :undiscarded, -> { unscope(where: discard_column).where(discard_column => nil) }
      scope :discarded, -> { unscope(where: discard_column).where.not(discard_column => nil) }
      scope :with_discarded, -> { unscope(where: discard_column) }

      # backward compatibility
      default_scope { kept }

      define_model_callbacks :discard
      define_model_callbacks :undiscard
    end

    # :nodoc:
    module ClassMethods
      def also_discards(*models, batch: false)
        models.each do |model|
          reflection = reflect_on_association(model)
          raise ArgumentError, "model `#{model}` must have an association by the name of `#{model}`" unless reflection

          # NOTE: to self: we used to introspect the reflection's klass here to
          # see if it was discardable. However, this lead to the associated class
          # being loaded, while this class is being loaded, which can easily lead
          # to circular dependencies. This check is now done later.

          self.additional_discard_associations << AdditionalDiscard.new([reflection], batch)
        end
      end

      # Discards the records by instantiating each
      # record and calling its {#discard} method.
      # Each object's callbacks are executed.
      # Returns the collection of objects that were discarded.
      #
      # Note: Instantiation, callback execution, and update of each
      # record can be time consuming when you're discarding many records at
      # once. It generates at least one SQL +UPDATE+ query per record (or
      # possibly more, to enforce your callbacks). If you want to discard many
      # rows quickly, without concern for their associations or callbacks, use
      # #update_all(deleted_at: Time.current) instead.
      #
      # ==== Examples
      #
      #   Person.where(age: 0..18).discard_each
      def discard_each(without_associations: false)
        kept.each { |record| record.discard(without_associations:) }
      end

      # Discards the records by instantiating each
      # record and calling its {#discard!} method.
      # Each object's callbacks are executed.
      # Returns the collection of objects that were discarded.
      #
      # Note: Instantiation, callback execution, and update of each
      # record can be time consuming when you're discarding many records at
      # once. It generates at least one SQL +UPDATE+ query per record (or
      # possibly more, to enforce your callbacks). If you want to discard many
      # rows quickly, without concern for their associations or callbacks, use
      # #update_all!(deleted_at: Time.current) instead.
      #
      # ==== Examples
      #
      #   Person.where(age: 0..18).discard_each!
      def discard_each!(without_associations: false)
        kept.each { |record| record.discard!(without_associations:) }
      end

      # Undiscards the records by instantiating each
      # record and calling its {#undiscard} method.
      # Each object's callbacks are executed.
      # Returns the collection of objects that were undiscarded.
      #
      # Note: Instantiation, callback execution, and update of each
      # record can be time consuming when you're undiscarding many records at
      # once. It generates at least one SQL +UPDATE+ query per record (or
      # possibly more, to enforce your callbacks). If you want to undiscard many
      # rows quickly, without concern for their associations or callbacks, use
      # #update_all(deleted_at: nil) instead.
      #
      # ==== Examples
      #
      #   Person.where(age: 0..18).undiscard_each
      def undiscard_each(without_associations: false)
        discarded.each { |record| record.undiscard(without_associations:) }
      end

      # Undiscards the records by instantiating each
      # record and calling its {#undiscard!} method.
      # Each object's callbacks are executed.
      # Returns the collection of objects that were undiscarded.
      #
      # Note: Instantiation, callback execution, and update of each
      # record can be time consuming when you're undiscarding many records at
      # once. It generates at least one SQL +UPDATE+ query per record (or
      # possibly more, to enforce your callbacks). If you want to undiscard many
      # rows quickly, without concern for their associations or callbacks, use
      # #update_all!(deleted_at: nil) instead.
      #
      # ==== Examples
      #
      #   Person.where(age: 0..18).undiscard_each!
      def undiscard_each!(without_associations: false)
        discarded.each { |record| record.undiscard!(without_associations:) }
      end

      # Discard all records in the relation which are not already discarded.
      # Generates one query but does not run callbacks.
      # @return [Integer] the number of records discarded
      delegate :discard_all, to: :all

      # Undiscard all records in the relation which are discarded.
      # Generates one query but does not run callbacks.
      # @return [Integer] the number of records undiscarded
      delegate :undiscard_all, to: :all

      # @return [Array] all nested discard associations
      def all_nested_discard_associations
        recurse_through_discard_associations(self)
      end

      private

      def recurse_through_discard_associations(model, parent_reflections = [], list = [])
        return list unless model.discardable?

        model.additional_discard_associations.each do |additional_discard|
          not_discardable = additional_discard.reflections.filter { |reflection| !reflection.klass.discardable? }
          raise ArgumentError, "reflections must be discardable but #{not_discardable} were not" if not_discardable.any?

          combined_reflections = additional_discard.reflections + parent_reflections

          list << additional_discard.with(reflections: combined_reflections)

          # recursive!
          recurse_through_discard_associations(
            additional_discard.reflections.first.klass,
            combined_reflections,
            list
          )
        end

        list
      end
    end

    # @return [Boolean] true if this record has been discarded, otherwise false
    def discarded?
      self[self.class.discard_column].present?
    end

    # @return [Boolean] false if this record has been discarded, otherwise true
    def undiscarded?
      !discarded?
    end
    alias kept? undiscarded?

    # Discard the record in the database
    #
    # @return [Boolean] true if successful, otherwise false
    def discard(without_associations: false)
      return false if discarded?

      run_callbacks(:discard) do
        self[self.class.discarder_id_column] = self.class.discarder_user.call&.id
        result = update_attribute(self.class.discard_column, Time.current)

        next result unless result
        next result if without_associations

        apply_operation_to_associations(discard: true)
      end
    end

    # Discard the record in the database
    #
    # There's a series of callbacks associated with #discard!. If the
    # <tt>before_discard</tt> callback throws +:abort+ the action is cancelled
    # and #discard! raises {Discard::RecordNotDiscarded}.
    #
    # @return [Boolean] true if successful
    # @raise {Discard::RecordNotDiscarded}
    def discard!(without_associations: false)
      discard(without_associations:) || _raise_record_not_discarded
    end

    # Undiscard the record in the database
    #
    # @param without_associations [Boolean] if true, do not undiscard associations
    # @return [Boolean] true if successful, otherwise false
    def undiscard(without_associations: false)
      return false unless discarded?

      run_callbacks(:undiscard) do
        self[self.class.discarder_id_column] = nil
        result = update_attribute(self.class.discard_column, nil)

        next result unless result
        next result if without_associations

        apply_operation_to_associations(discard: false)
      end
    end

    # Discard the record in the database
    #
    # There's a series of callbacks associated with #undiscard!. If the
    # <tt>before_undiscard</tt> callback throws +:abort+ the action is cancelled
    # and #undiscard! raises {Discard::RecordNotUndiscarded}.
    #
    # @return [Boolean] true if successful
    # @raise {Discard::RecordNotUndiscarded}
    def undiscard!(without_associations: false)
      undiscard(without_associations:) || _raise_record_not_undiscarded
    end

    private

    def apply_operation_to_associations(discard:)
      result = true

      # this class is the originator of the discard request
      this_class = self.class
      this_pk_eq = this_class.arel_table[this_class.primary_key].eq(self[this_class.primary_key])

      this_class.all_nested_discard_associations.each do |additional_discard|
        result &&= apply_operation(discard, additional_discard, this_pk_eq)

        break unless result
      end

      result
    end

    def apply_operation(discard, additional_discard, this_pk_eq)
      scope = generate_scope_between_this_and_target(additional_discard.reflections, this_pk_eq)

      batch = additional_discard.batch

      if discard && batch
        scope.discard_all
      elsif discard && !batch
        scope.discard_each
      elsif !discard && batch
        scope.undiscard_all
      elsif !discard && !batch
        scope.undiscard_each
      end
    end

    def generate_scope_between_this_and_target(reflections, this_pk_eq)
      # the target class is the one we want to discard
      target_reflection = reflections.first
      target_class = target_reflection.klass

      # now we need to build the joins between the target class and the originator
      # we're heading up the tree, so we need to join from the target to the originator
      joins = target_class.arel_table
      reflections
        # deals with has many through associations
        .flat_map(&:collect_join_chain)
        .each do |reflection|
        raise NotImplementedError, 'no support for association scopes' if reflection.scope

        child_class = reflection.klass
        parent_class = if reflection.belongs_to?
                         reflection.active_record
                       elsif reflection.through_reflection?
                         # through reflections don't define an inverse of, so we need to use the through reflection
                         reflection.through_reflection.klass
                       else
                         reflection.inverse_of.klass
                       end
        child_table = child_class.arel_table
        parent_table = parent_class.arel_table

        foreign_key = reflection.foreign_key
        primary_key = reflection.active_record_primary_key

        # belongs_to associations have key and primary key reversed for their classes
        foreign_key, primary_key = primary_key, foreign_key if reflection.belongs_to?

        joins
          .join(parent_table)
          .on(child_table[foreign_key].eq(parent_table[primary_key])) => joins
      end

      # add the joins to a target class relation, and filter by the originator's primary key
      target_class.joins(joins.join_sources).where(this_pk_eq)
    end

    def _raise_record_not_discarded
      raise ::Discardable::RecordNotDiscarded.new('Failed to discard the record', self)
    end

    def _raise_record_not_undiscarded
      raise ::Discardable::RecordNotUndiscarded.new('Failed to undiscard the record', self)
    end
  end
end
