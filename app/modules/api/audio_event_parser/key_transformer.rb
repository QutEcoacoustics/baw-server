# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Recognizes one of multiple keys from a hash and optionally transforms it
    class KeyTransformer
      attr_accessor :keys, :multi, :default

      def initialize(*keys, multi: false, default: nil)
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
        }.uniq
        @keys = keys
        @multi = multi
        @default = default
      end

      # Search a hash for any number of possible variants of a key.
      # If found remove the key from the hash.
      # @return [Array(Hash,Symbol,(Object|Array<Object>))] the modified hash, the variant of the key found, and the value in that order
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

        values = [default] if values.blank?

        values = values.flatten.compact

        if multi
          values.blank? ? default : values
        else
          values.first || default
        end
      end

      def transform(_key, value)
        # noop
        value
      end
    end
  end
end
