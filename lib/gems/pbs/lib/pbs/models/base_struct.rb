# frozen_string_literal: true

module PBS
  module Models
    # Common recipe for models
    class BaseStruct < ::Dry::Struct
      # https://dry-rb.org/gems/dry-struct/1.0/recipes/

      # downcase all keys, json payload has inconsistent capitalization
      # allow transforming keys to symbols
      transform_keys do |key|
        key.to_s.downcase.to_sym
      end
    end
  end
end
