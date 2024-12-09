# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Recognizes one of multiple keys from a hash and optionally transforms it
    class KeyTransformer
      include Dry::Monads[:maybe]

      # @return [Set<Symbol>] the keys to look for
      attr_accessor :keys

      # @return [Boolean] whether to look for multiple keys
      attr_reader :multi

      def initialize(*keys, multi: false)
        # augment keys to allow us to look for different variants
        keys = keys.flat_map { |x|
          [
            x,
            # matches CSV's symbolize converter, placed first to ensure quick match
            x.to_s.downcase.gsub(/[^\s\w]+/, '').strip.gsub(/\s+/, '_').to_sym,
            x.to_s.camelize.to_sym,
            x.to_s.camelize(:lower).to_sym,
            x.to_s.titleize.to_sym,
            x.to_s.gsub(' ', '_').underscore.to_sym
          ]
        }
        @keys = Set.new(keys)
        @multi = multi
      end

      # Search a hash for any number of possible variants of a key.
      # If found remove the key from the hash.
      # @param [Hash] hash the hash to search
      # @return [Maybe<Object>] the value of the key if found, otherwise `None`
      def extract_key(hash)
        key = nil
        values = []

        keys.each do |target|
          next unless hash.key?(target)

          key = target
          value = hash[target]

          value = transform(key, value)

          values << value
          break unless multi
        end

        return None() if values.blank?

        values
          .flatten
          .compact
          .if_then(!multi, &:first)
          .then(&Some)
      end

      def transform(_key, value)
        # noop
        value
      end
    end
  end
end
