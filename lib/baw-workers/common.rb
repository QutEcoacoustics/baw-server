require 'active_support/concern'
module BawWorkers
  # Common functionality.
  module Common
    extend ActiveSupport::Concern

    module ClassMethods

      def validate_contains(value, hash)
        unless hash.include?(value)
          msg = "Media type '#{value}' is not in list of valid media types '#{hash}'."
          fail ArgumentError, msg
        end
      end

      def validate_hash(hash)
        fail ArgumentError, "Media request params was a '#{hash.class}'. It must be a 'Hash'. '#{hash}'." unless hash.is_a?(Hash)
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

      # Get the key for resque_solo to use in redis.
      def redis_key(payload)
        BawWorkers::ResqueJobId.create_id_payload(payload)
      end

      # Overrides method used by resque-status.
      # Uses resque_solo redis key instead of random uuid.
      # Adds a job of type <tt>klass<tt> to a specified queue with <tt>options<tt>.
      #
      # Returns the UUID of the job if the job was queued, or nil if the job was
      # rejected by a before_enqueue hook.
      def enqueue_to(queue, klass, options = {})
        uuid = BawWorkers::ResqueJobId.create_id_props(klass, options)
        Resque::Plugins::Status::Hash.create uuid, :options => options

        if Resque.enqueue_to(queue, klass, uuid, options)
          uuid
        else
          Resque::Plugins::Status::Hash.remove(uuid)
          nil
        end
      end

    end

    def get_class_name
      self.class.name
    end

  end
end