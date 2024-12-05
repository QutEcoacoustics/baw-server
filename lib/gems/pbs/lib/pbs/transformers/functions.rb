# frozen_string_literal: true

require 'dry/transformer/recursion'
require 'dry/transformer/conditional'

module PBS
  module Transformers
    # helper functions and patches
    module Functions
      Inflector = Dry::Inflector.new
      extend Dry::Transformer::Registry

      import Dry::Transformer::ArrayTransformations
      import Dry::Transformer::HashTransformations
      import Dry::Transformer::ClassTransformations
      import Dry::Transformer::Conditional
      import Dry::Transformer::Recursion

      def self.normalize_key(key)
        Inflector.underscore(key).to_sym
      end

      def self.parse_json(string)
        JSON.parse(string, PBS::Connection::JSON_PARSER_OPTIONS)
      end

      # map values of a hash
      # @param hash [Hash]
      # @param function [Proc] function is called with |key, value| and is expected to return a value
      # @return [Hash]
      def self.map_values_with_key(hash, function)
        hash.to_h { |key, value| [key, function.call(key, value)] }
      end

      # there is a bug where map_values does not accept a Dry::Transformer::Composite
      # so I'm trying to override their function
      def self.map_hash_values(source_hash, function)
        # https://github.com/dry-rb/dry-transformer/blob/da12afdc1f96a4172dab277f231d5b87a18e0c57/lib/dry/transformer/hash_transformations.rb#L136-L138
        # in their code, they call transform_values! which type checks the
        # callback ensuring it is a proc
        source_hash&.transform_values! do |value|
          function.call(value)
        end
      end

      def self.embed_key_into_value(key, value, new_key)
        value.merge(new_key => key)
      end

      # parse the depend string from a pbs job
      def self.parse_depend(value)
        return nil if value.blank?

        value.split(',').to_h { |item|
          key, *values = item.split(':')
          [key.to_sym, values]
        }
      end
    end
  end
end
