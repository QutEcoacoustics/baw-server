# frozen_string_literal: true

module BawWorkers
  class DecodeException < StandardError
  end

  class RedisCommunicator
    attr_accessor :logger

    # Create a new BawWorkers::ApiCommunicator.
    # @param [Object] logger
    # @param [Object] redis_instance
    # @param [Object] settings
    # @return [BawWorkers::RedisCommunicator]
    def initialize(logger, redis_instance, settings = {})
      raise '`redis_instance` must be a valid Redis instance' unless redis_instance.is_a?(Redis)

      @logger = logger
      @redis = redis_instance
      @settings = settings

      @class_name = self.class.name
    end

    def namespace
      @settings[:namespace] || 'baw-workers'
    end

    def add_namespace(key)
      "#{namespace}:#{key}"
    end

    # @return [Redis]
    attr_reader :redis

    # Delete a single key.
    # @param [String] key
    # @return [Boolean]
    def delete(key, opts = {})
      key = add_namespace(key) unless opts[:no_namespace]

      deleted = @redis.del(key)

      # Technically the server could delete multiple keys. Since we consider this undefined behaviour at this point
      # in time we throw. In the future we may support deleting multiple keys.
      raise 'Too many keys deleted' if deleted > 1

      deleted == 1
    end

    # Deletes all keys that have at least the given key as a prefix
    # @param [String] the key prefix to delete. A wildcard is added as a suffix
    # @return [Boolean] if any keys were deleted
    def delete_all(key)
      raise ArgumentError if key.blank?

      count = 0
      @redis.keys("#{key}*").each do |k|
        count += @redis.del k
      end

      count.positive?
    end

    # @param [String] key
    # @param [Hash] opts
    # @return [Boolean]
    def exists(key, opts = {})
      key = add_namespace(key) unless opts[:no_namespace]

      @redis.exists?(key)
    end

    # @param [String] key
    # @param [Hash] opts
    # @return [Boolean]
    def exists?(key, opts = {})
      key = add_namespace(key) unless opts[:no_namespace]

      @redis.exists?(key)
    end

    # @param [String] key
    # @return [Hash]
    def get(key, opts = {})
      key = add_namespace(key) unless opts[:no_namespace]

      value = @redis.get(key)
      decode(value)
    end

    # Set the redis string with to assigned value
    # @param [Object] value
    # @param [String] key
    # @return [Boolean]
    # @param [Hash] opts
    def set(key, value, opts = {})
      key = add_namespace(key) unless opts[:no_namespace]

      opts[:key] = key

      result = @redis.set(key, encode(value), ex: opts[:expire_seconds])

      boolify(result)
    end

    FILE_EXPIRE_SECONDS = 60
    BINARY_ENCODING = Encoding::ASCII_8BIT

    def set_file(key, path)
      raise ArgumentError, 'key must not be blank' if key.blank?

      path = Pathname(path)
      raise ArgumentError, 'path does not exist' unless path.exist?

      # sanitize the name
      key = safe_file_name(key)
      key = add_namespace(key)

      result = logger.measure_debug('storing large binary key', payload: { key: key, size: path.size }) {
        @redis.set(
          key.force_encoding(BINARY_ENCODING),
          File.binread(path),
          ex: FILE_EXPIRE_SECONDS
        )
      }

      boolify(result)
    end

    # practically the same as exist but applies safe file name transform
    # to the key parameter first.
    def exists_file?(key)
      # sanitize the name
      key = safe_file_name(key)
      key = add_namespace(key)

      redis.exists?(key)
    end

    def delete_file(key)
      # sanitize the name
      key = safe_file_name(key)
      key = add_namespace(key)

      redis.del(key) == 1
    end

    # @return [Integer] the number of bytes written
    def get_file(key, dest)
      key = safe_file_name(key)
      key = add_namespace(key)

      # delay opening IO until we've fetched a key, otherwise there's a chance we could
      # truncate a file before we know if the fetch was successful
      io = nil
      if BawWorkers::IO.io_ish?(dest)
        open_io = -> { dest }
      else
        dest = Pathname(dest)
        # make containing directory
        dest.parent.mkpath

        logger.warn("Overwriting file at #{dest}") if dest.exist?

        open_io = -> { File.open(dest, 'wb:ASCII-8BIT') }
      end

      begin
        result = logger.measure_debug('fetching large binary key', payload: { key: key, dest: dest.to_s }) {
          # i say binary response, but it's just a string
          binary_response = @redis.get(key.force_encoding(BINARY_ENCODING))
          return nil if binary_response.nil?

          binary_response.force_encoding(BINARY_ENCODING)

          # open, write, continue
          io = open_io.call
          io.binmode
          io.write(binary_response)
        }

        logger.warn('io must have binary encoding') unless io.external_encoding == BINARY_ENCODING

        result
      ensure
        io&.close
      end
    end

    # Get the time to live (in seconds) for a key.
    #
    # @param [String] key
    # @return [Integer] remaining time to live in seconds.
    #
    #     - The command returns -2 if the key does not exist.
    #     - The command returns -1 if the key exists but has no associated expire.
    def ttl(key)
      key = add_namespace(key)
      @redis.ttl(key)
    end

    # Checks to see if we can contact redis
    # @return [String] `PONG` - if successful
    def ping
      @redis.ping
    end

    # Given a Ruby object, returns a string suitable for storage in a
    # queue.
    # Blatantly lifted from: https://github.com/resque/resque/blob/d0e187881e02d852f8e4755aef3c14319636527b/lib/resque.rb#L30
    def encode(object)
      if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
        MultiJson.dump object
      else
        MultiJson.encode object
      end
    end

    # Given a string, returns a Ruby object.
    # Blatantly lifted from: https://github.com/resque/resque/blob/d0e187881e02d852f8e4755aef3c14319636527b/lib/resque.rb#L44
    def decode(object)
      return unless object

      begin
        if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
          MultiJson.load object
        else
          MultiJson.decode object
        end
      rescue ::MultiJson::DecodeError => e
        raise DecodeException, e.message, e.backtrace
      end
    end

    private

    def safe_file_name(key)
      key.to_s.strip.tr("\u{202E}%$|*[]:;/\t\r\n\\ ", '-')
    end

    def boolify(value)
      value.is_a?(String) && value == 'OK'
    end
  end
end
