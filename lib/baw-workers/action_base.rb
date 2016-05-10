module BawWorkers
  # Common functionality for resque actions.
  class ActionBase

    # Ensure that there is only one job with the same payload per queue.
    # The default method to create a job ID from these parameters is to
    # do some normalization on the payload and then md5'ing it
    include Resque::Plugins::UniqueJob

    # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
    # Jobs performed
    # Jobs enqueued
    # Jobs failed
    # Duration of last x jobs completed
    # Average job duration over last 100 jobs completed
    # Longest job duration over last 100 jobs completed
    # Jobs enqueued as timeseries data (minute, hour, day)
    # Jobs performed as timeseries data (minute, hour, day)
    extend Resque::Plugins::JobStats

    # track specific job instances and their status.
    # resque-status achieves this by giving job instances UUID's
    # and allowing the job instances to report their
    # status from within their iterations.
    include Resque::Plugins::Status

    class << self

      # Override: Get the key for resque_solo to use in redis.
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

      # By default, lock_after_execution_period is 0 and enqueued? becomes
      # false as soon as the job is being worked on.
      # The lock_after_execution_period setting can be used to delay when
      # the unique job key is deleted (i.e. when enqueued? becomes false).
      # For example, if you have a long-running unique job that takes around
      # 10 seconds, and you don't want to requeue another job until you are
      # sure it is done, you could set lock_after_execution_period = 20.
      # Or if you never want to run a long running job more than once per
      # minute, set lock_after_execution_period = 60.
      # @return [Fixnum]
      def lock_after_execution_period
        # 2 minutes
        120
      end

      # Get the queue for this action. Used by Resque. Overrides resque-status class method.
      # @return [Symbol] The queue.
      def queue
        fail NotImplementedError, 'Must implement `queue` method.'
      end

      # Name for logging.
      def logger_name
        self.name
      end

    end

    # Get the keys for the perform options hash.
    # order is important
    # @return [Array<String>]
    def perform_options_keys
      fail NotImplementedError, 'Must implement `perform_options_keys`.'
    end

    # Perform method used by resque-status.
    def perform
      values = perform_options_keys.map { |k| options[k] }
      self.class.action_perform(*values)
    end

  end
end