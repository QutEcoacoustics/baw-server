# frozen_string_literal: true

require 'json'
require 'dry/transformer'

module Emu
  # A dry transformer to convert a JSON string into a hash.
  class JsonAdapter < Dry::Transformer::Pipe
    JSON_PARSER_OPTIONS = {
      allow_nan: true
    }.freeze

    import Dry::Transformer::HashTransformations
    import Dry::Transformer::ClassTransformations
    import Dry::Transformer::Recursion
    import Dry::Transformer::Conditional
    import Dry::Transformer::Coercions

    Inflector = Dry::Inflector.new
    import :underscore, from: Inflector, as: :underscore

    def parse_json(string)
      ::JSON.parse(string, JSON_PARSER_OPTIONS)
    end

    define! do
      parse_json

      recursion do
        is(Hash) do
          map_keys do
            # convert the key to underscore case and symbolize unless it contains a digit
            # this rule is a little over-specific but we're trying to ensure keys that should
            # remain strings (like 'FL0101') do not get modified
            guard(->(k) { k !~ /\d/ }) do
              underscore
              to_symbol
            end
          end

          #symbolize_keys

          constructor_inject(ActiveSupport::HashWithIndifferentAccess)
        end
      end
    end
  end
end
