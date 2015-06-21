require 'pathname'

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

      PATH_REGEXP = /\A(?:[0-9a-zA-Z_\-\.\/])+\z/

      def validate_file(value, check_exists = true)
        fail ArgumentError, 'File path cannot be empty.' if value.blank?
        fail ArgumentError, "File path is not valid #{value}." unless PATH_REGEXP === value

        file = Pathname.new(value).cleanpath

        fail ArgumentError, "File path must be absolute #{value}." if file.relative?
        fail ArgumentError, "Could not find file #{value}." if check_exists && !file.file?

        file.to_s
      end

      def validate_files(value, check_exists = true)
        is_array = value.is_a?(Array)
        is_string = value.is_a?(String)
        is_pathname = value.is_a?(Pathname)

        if is_string
          [validate_file(value, check_exists)]
        elsif is_pathname
          [validate_file(value.to_s, check_exists)]
        elsif is_array
          value.map{ |i| validate_file(i.to_s, check_exists)}
        end

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

      # Check that the value for real_run is valid.
      # @param [String] real_run
      # @return [Boolean] true for a real run, false for dry run.
      def check_real_run(real_run)
        # options are 'dry_run' or 'real_run'. If not either of these, raise an erorr.
        fail ArgumentError, "real_run must be 'dry_run' or 'real_run', given '#{real_run}'." if real_run.blank? || !%w(real_run dry_run).include?(real_run)
        (real_run == 'real_run') ? true : false
      end

      # Check that the value for copy_on_success is valid.
      # @param [String] copy_on_success
      # @return [Boolean] true to copy on success, false to not copy.
      def check_copy_on_success(copy_on_success)
        # options are 'dry_run' or 'real_run'. If not either of these, raise an erorr.
        fail ArgumentError, "copy_on_success must be 'no_copy' or 'copy_on_success', given '#{copy_on_success}'." if copy_on_success.blank? || !%w(no_copy copy_on_success).include?(copy_on_success)
        (copy_on_success == 'copy_on_success') ? true : false
      end

      # Compare actual and expected objects.
      # @see https://github.com/amogil/rspec-deep-ignore-order-matcher/blob/master/lib/rspec-deep-ignore-order-matcher.rb
      def compare(actual, expected)
        if expected.is_a?(Array) && actual.is_a?(Array)
          compare_array(actual, expected)
        elsif expected.is_a?(Hash) && actual.is_a?(Hash)
          compare_hash(actual, expected)
        else
          expected == actual
        end
      end

      def compare_array(actual, expected)
        exp = expected.clone
        actual.each do |a|
          index = exp.find_index { |e| compare(a, e) }
          return false if index.nil?
          exp.delete_at(index)
        end
        exp.length == 0
      end

      def compare_hash(actual, expected)
        return false unless (actual.keys - expected.keys).length == 0
        actual.each { |key, value| return false unless compare(value, expected[key]) }
        true
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
        deep_transform_keys(hash) { |key| key.to_sym rescue key }
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
            object.map { |e| _deep_transform_keys_in_object(e, &block) }
          else
            object
        end
      end

    end
  end
end