# frozen_string_literal: true

module Discardable
  # Handles soft deletes of records in a relation.
  module Relation
    extend ActiveSupport::Concern

    # ActiveRecord::Relation defines `klass` which is the model class.

    delegate :discardable?, to: :klass

    # Discard all records in the relation which are not already discarded.
    # Generates one query but does not run callbacks.
    # @return [Integer] the number of records discarded
    def discard_all(**attrs)
      raise NotDiscardableError unless discardable?

      kept.update_all(
        klass.discard_column => Time.current,
        klass.discarder_id_column => klass.discarder_user.call&.id,
        **attrs
      )
    end

    # Undiscard all records in the relation which are discarded.
    # Generates one query but does not run callbacks.
    # @return [Integer] the number of records undiscarded
    def undiscard_all(**attrs)
      raise NotDiscardableError unless discardable?

      discarded.update_all(
        klass.discard_column => nil,
        klass.discarder_id_column => nil,
        **attrs
      )
    end
  end
end
