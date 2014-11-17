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

      # from ActiveSupport 4
      # Returns a new hash with all keys converted to symbols, as long as
      # they respond to +to_sym+. This includes the keys from the root hash
      # and from all nested hashes and arrays.
      #
      #   hash = { 'person' => { 'name' => 'Rob', 'age' => '28' } }
      #
      #   hash.deep_symbolize_keys
      #   # => {:person=>{:name=>"Rob", :age=>"28"}}
      def deep_symbolize_keys(hash)
        deep_transform_keys(hash){ |key| key.to_sym rescue key }
      end

      # from ActiveSupport 4
      # Returns a new hash with all keys converted by the block operation.
      # This includes the keys from the root hash and from all
      # nested hashes and arrays.
      #
      #  hash = { person: { name: 'Rob', age: '28' } }
      #
      #  hash.deep_transform_keys{ |key| key.to_s.upcase }
      #  # => {"PERSON"=>{"NAME"=>"Rob", "AGE"=>"28"}}
      def deep_transform_keys(hash, &block)
        _deep_transform_keys_in_object(hash, &block)
      end

      # from ActiveSupport 4
      # support methods for deep transforming nested hashes and arrays
      def _deep_transform_keys_in_object(object, &block)
        case object
          when Hash
            object.each_with_object({}) do |(key, value), result|
              result[yield(key)] = _deep_transform_keys_in_object(value, &block)
            end
          when Array
            object.map {|e| _deep_transform_keys_in_object(e, &block) }
          else
            object
        end
      end

    end
  end
end