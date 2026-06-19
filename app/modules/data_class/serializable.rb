# frozen_string_literal: true

module DataClass
  # Shared behaviour for the plain form objects in this namespace.
  #
  # Declaring attributes with `attribute` defines accessors and records their
  # names, which lets an instance serialize itself. `DataClassSerializer` uses
  # this so the objects can be passed as arguments to mailers delivered
  # asynchronously with `deliver_later`.
  module Serializable
    extend ActiveSupport::Concern

    class_methods do
      # Declare one or more attributes for the form object. Defines accessors
      # and records the names so the object can serialize itself.
      def attribute(*names)
        attr_accessor(*names)

        serializable_attribute_names.concat(names)
      end

      def serializable_attribute_names
        @serializable_attribute_names ||= []
      end

      # Build an instance from a previously serialized attribute hash.
      def from_serialized_attributes(attributes)
        new(attributes.symbolize_keys)
      end
    end

    # The attribute values keyed by name, coerced to plain strings (e.g.
    # Enumerize values) while preserving nil, suitable for JSON serialization.
    def serialized_attributes
      self.class.serializable_attribute_names.to_h do |name|
        [name.to_s, public_send(name)&.to_s]
      end
    end
  end
end
