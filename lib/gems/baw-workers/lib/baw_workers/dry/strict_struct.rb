# frozen_string_literal: true

module BawWorkers
  module Dry
    # A set of defaults for a Dry::Struct that transforms keys and uses a
    # strict schema
    class StrictStruct < ::Dry::Struct
      # # Allows a struct to be serialized into JSON by first converting it to a hash
      # raise 'to_json not needed' if method_defined?(:to_h)

      # def to_json(*args)
      #   to_h.to_json(*args)
      # end

      # https://dry-rb.org/gems/dry-struct/1.0/recipes/
      # allow transforming keys to symbols
      transform_keys(&:to_sym)
      # don't allow keys other than what is expected
      schema schema.strict
    end
  end
end
