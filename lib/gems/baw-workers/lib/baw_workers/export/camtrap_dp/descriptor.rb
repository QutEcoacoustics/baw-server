# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # This module defines a base struct class for Camtrap-DP descriptor objects, with custom behavior for JSON
      # serialization and default value handling.
      class Descriptor < ::Dry::Struct
        Types = BawWorkers::Dry::Types

        # Override the default to_h method to remove nil values with compact.
        #
        # We use explicit nil values for optional fields for clarity and maintainability, but null values in the package
        # output raise type errors during validation unless the type allows it.
        def to_h
          self.class.schema.each_with_object({}) do |key, result|
            result[key.name] = ::Dry::Struct::Hashify[self[key.name]] if attributes.key?(key.name)
            result.compact!
          end
        end
      end
    end
  end
end
