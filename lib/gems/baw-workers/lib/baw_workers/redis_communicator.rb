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
      namespace + ':' + key
    end

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
      @redis.keys(key + '*').each do |k|
        count += @redis.del k
      end

      count.positive?
    end

    # @param [String] key
    # @param [Hash] opts
    # @return [Boolean]
    def exists(key, opts = {})
      key = add_namespace(key) unless opts[:no_namespace]

      @redis.exists(key)
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

      set_opts = {}
      set_opts[:ex] = opts[:expire_seconds] if opts[:expire_seconds]
      result = @redis.set(key, encode(value), set_opts)

      boolify(result)
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

    def boolify(value)
      if value&.is_a?(String) && value == 'OK'
        true
      else
        false
      end
    end
  end
end
