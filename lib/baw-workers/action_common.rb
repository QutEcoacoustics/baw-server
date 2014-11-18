require 'active_support/concern'
module BawWorkers
  # Common functionality for actions.
  module ActionCommon
    extend ActiveSupport::Concern

    module ClassMethods

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

      # validate a file path
      def validate_path(value)
        fail ArgumentError, 'File path cannot be empty.' if value.blank?
        fail ArgumentError, "Could not find file #{value}." unless File.file?(value)
        File.expand_path(value)
      end

    end

  end
end