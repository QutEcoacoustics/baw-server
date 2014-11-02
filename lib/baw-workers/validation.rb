module BawWorkers
  # Common validation methods.
  class Validation

    class << self

      def validate_contains(value, hash)
        unless hash.include?(value)
          msg = "Media type '#{value}' is not in list of valid media types '#{hash}'."
          fail ArgumentError, msg
        end
      end

      def validate_hash(hash)
        fail ArgumentError, "Param was a '#{hash.class}'. It must be a 'Hash'. '#{hash}'." unless hash.is_a?(Hash)
      end

      def symbolize_hash_keys(hash)
        Hash[hash.map { |k, v| [k.to_sym, v] }]
      end

      def symbolize(value, hash)
        [value.to_sym, symbolize_hash_keys(hash)]
      end

      def check_datetime(value)
        # ensure datetime_with_offset is an ActiveSupport::TimeWithZone
        if value.is_a?(ActiveSupport::TimeWithZone)
          value
        else
          fail ArgumentError, "Must provide a value for datetime_with_offset: '#{value}'." if value.blank?
          result = Time.zone.parse(value)
          fail ArgumentError, "Provided value for datetime_with_offset is not valid: '#{result}'." if result.blank?
          result
        end
      end

    end
  end
end