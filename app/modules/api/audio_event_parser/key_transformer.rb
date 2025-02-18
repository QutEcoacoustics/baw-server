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

      # @return [Boolean] whether to allow nil values
      # @note this is useful for keys that are optional
      attr_reader :allow_nil

      def initialize(*keys, multi: false, allow_nil: false)
        # augment keys to allow us to look for different variants
        keys = keys.flat_map { |x|
          [
            x,
            # matches CSV's symbolize converter, placed first to ensure quick match
            x.to_s.downcase.gsub(/[^\s\w]+/, '').strip.gsub(/\s+/, '_').to_sym,
            x.to_s.camelize.to_sym,
            x.to_s.camelize(:lower).to_sym,
            x.to_s.titleize(keep_id_suffix: true).to_sym,
            x.to_s.gsub(' ', '_').underscore.to_sym

          ]
        }

        @keys = Set.new(keys)
        @multi = multi
        @allow_nil = allow_nil
      end

      # Search a hash for any number of possible variants of a key.
      # If found remove the key from the hash.
      # Values are transformed before being returned.
      # @param [Hash] hash the hash to search
      # @return [::Dry::Monads::Maybe<Object>] the transformed value of the key if found, otherwise `None`
      def extract_key(hash)
        key = nil
        values = []

        keys.each do |target|
          next unless hash.key?(target)

          key = target
          value = hash[target]

          if value.blank?
            values << nil if allow_nil
          else
            new_value = transform(key, value)
            # so we've found a key in the value.
            # transform normalizes, but if it fails, we keep the original value
            # so the validation can catch it.
            values << (new_value.some? ? new_value.value! : value)
          end

          break if values.any? && !multi
        end

        return None() if values.blank?

        values
          .flatten
          .if_then(!multi, &:first)
          .then(&Some)
      end

      # Transform a value
      # Note: avoid coercion here. The point of this method is normalize values
      # for valid formats. Invalid formats should be caught by the validation.
      # If a value is invalid, return `None` to indicate that the key should be ignored.
      # `value` is guaranteed to be non-nil and non-blank.
      # @param [Symbol] key the key that was found
      # @param [Object] value the value to transform
      # @return [::Dry::Monads::Maybe<Object>] the possibly transformed value
      def transform(_key, value)
        # noop
        Some(value)
      end
    end
  end
end
