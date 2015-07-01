require 'pathname'

module BawWorkers
  # Common validation methods.
  class Validation

    PATH_REGEXP = /\A(?:[0-9a-zA-Z_\-\.\/])+\z/
    INVALID_CHARS_REGEXP = /[^0-9a-z\-\._\\\/]/i
    TOP_DIR_VALID_CHARS_REGEXP = /[0-9a-z\-_]/i
    UUID_REGEXP = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    class << self

      # true / false validation

      # Is this a uuid?
      # @param [String] uuid
      # @return [Boolean]
      def is_uuid?(uuid)
        uuid =~ UUID_REGEXP
      end

      # Check that the value for real_run is valid.
      # @param [String] real_run
      # @return [Boolean] true for a real run, false for dry run.
      def is_real_run?(real_run)
        # options are 'dry_run' or 'real_run'. If not either of these, raise an erorr.
        if real_run.blank? || !%w(real_run dry_run).include?(real_run)
          fail ArgumentError, "real_run must be 'dry_run' or 'real_run', given '#{real_run}'."
        end
        real_run == 'real_run'
      end

      # Check that the value for copy_on_success is valid.
      # @param [String] copy_on_success
      # @return [Boolean] true to copy on success, false to not copy.
      def should_copy_on_success?(copy_on_success)
        # options are 'dry_run' or 'real_run'. If not either of these, raise an erorr.
        if copy_on_success.blank? || !%w(no_copy copy_on_success).include?(copy_on_success)
          fail ArgumentError, "copy_on_success must be 'no_copy' or 'copy_on_success', given '#{copy_on_success}'."
        end
        copy_on_success == 'copy_on_success'
      end

      # validation that might raise errors, but has no useful return value

      # Check that an object is a hash.
      # @param [Hash] hash
      # @return [void]
      def check_hash(hash)
        fail ArgumentError, "Param was a '#{hash.class}'. It must be a 'Hash'. '#{hash}'." unless hash.is_a?(Hash)
      end

      # Check that a hash contains expected keys.
      # @param [Hash] hash
      # @param [Array] expected_keys
      # @return [void]
      def check_custom_hash(hash, expected_keys)
        fail ArgumentError, 'Hash must not be blank.' if hash.blank?
        check_hash(hash)
        fail ArgumentError, "Keys for #{hash} must not be empty." if expected_keys.blank?
        fail ArgumentError, "Keys for #{hash} must be an array." unless expected_keys.is_a?(Array)

        expected_keys.each do |key|
          fail ArgumentError, "Hash #{hash} must include key '#{key}'." unless hash.include?(key)
          fail ArgumentError, "Value in hash #{hash} for #{key} must not be nil." if hash[key].nil?
        end
      end

      # Check that a key is contained in a hash.
      # @param [Object] key
      # @param [Hash] hash
      # @return [void]
      def check_hash_contains(key, hash)
        unless hash.include?(key)
          msg = "Media type '#{key}' is not in list of valid media types '#{hash}'."
          fail ArgumentError, msg
        end
      end

      # methods that might raise errors and normalise/modify the parameters.

      #
      def normalise_file(value, check_exists = true)
        file = Pathname.new(normalise_path(value)).cleanpath
        fail ArgumentError, "Could not find file #{file}." if check_exists && !file.file?
        file.to_s
      end

      def normalise_files(value, check_exists = true)
        is_array = value.is_a?(Array)
        is_string = value.is_a?(String)

        if is_string
          [normalise_file(value, check_exists)]
        elsif is_array
          value.map { |i| normalise_file(i.to_s, check_exists) }
        else
          [normalise_file(value.to_s, check_exists)]
        end

      end

      def normalise_path(path, top_level_dir = nil)
        fail ArgumentError, 'Path cannot be empty.' if path.blank?

        # first replace '..', '~', '//', '\\', '/./', '\.\'
        # ensure no double or more slashes
        replace_char = '_'

        safer_path = path.dup
        safer_path = safer_path.gsub('..', replace_char)
        safer_path = safer_path.gsub('~', replace_char)
        safer_path = safer_path.gsub(/\/+/i, '/')
        safer_path = safer_path.gsub(/\\+/i, '\\')
        safer_path = safer_path.gsub('/.', "#{File::SEPARATOR}#{replace_char}")
        safer_path = safer_path.gsub('\\.', "#{File::SEPARATOR}#{replace_char}")

        safer_path = replace_char if safer_path == '.' || safer_path == '..'

        unless top_level_dir.blank?

          # ensure top level dir does not have any path traversal or anything else
          safer_top_level_dir = normalise_path(top_level_dir)
          safer_top_level_dir = File.expand_path(safer_top_level_dir)

          # expands to absolute path (also expands ~)
          safer_path = File.expand_path(safer_path, safer_top_level_dir)

          # ensure path starts with top_level_dir
          unless safer_path.start_with?(safer_top_level_dir)
            fail ArgumentError, "Path #{path} with base directory #{top_level_dir} was normalised to #{safer_path} using #{safer_top_level_dir}. It is not valid."
          end

          fail ArgumentError, "Path must start with / but got #{safer_path}." unless safer_path.start_with?('/')

        end

        # ensures . and .. are expanded
        cleaned = Pathname.new(safer_path).cleanpath

        # replace all invalid chars with an underscore. Don't collapse as double underscore has special meaning.
        cleaned.to_s.gsub(INVALID_CHARS_REGEXP, '_')
      end

      # Ensure value is a ActiveSupport::TimeWithZone.
      # @param [Object] value
      # @return [ActiveSupport::TimeWithZone]
      def normalise_datetime(value)
        fail ArgumentError, 'Expected value to be a ActiveSupport::TimeWithZone, got blank.' if value.blank?

        return value if value.is_a?(ActiveSupport::TimeWithZone)

        parse_error = nil
        begin
          result = Time.zone.parse(value.to_s)
        rescue => e
          parse_error = e
        end

        fail ArgumentError, "Could not parse ActiveSupport::TimeWithZone from #{value}." if result.blank?
        fail ArgumentError, "Error parsing #{value} to ActiveSupport::TimeWithZone: #{parse_error}." unless parse_error.blank?

        result
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