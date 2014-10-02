module BawWorkers
  module Harvest
    # Harvests files enqueued in redis.
    class Action

      # include common methods
      include BawWorkers::Common

      # Ensure that there is only one job with the same payload per queue.
      include Resque::Plugins::UniqueJob

      # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
      extend Resque::Plugins::JobStats

      # All methods do not require a class instance.
      class << self

        # Delay when the unique job key is deleted (i.e. when enqueued? becomes false).
        # @return [Fixnum]
        def lock_after_execution_period
          30
        end

        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        def queue
          BawWorkers::Settings.resque.queues.harvest
        end

        # Enqueue a single file for harvesting.
        # @param [Hash] harvest_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def enqueue(harvest_params)
          # harvest_params_sym = AudioFileCheck.validate(harvest_params)
          # result = Resque.enqueue(HarvestAction, harvest_params_sym)
          # BawWorkers::Settings.logger.info(self.name) {
          #   "Enqueued from HarvestAction. Resque enqueue returned #{result} using #{harvest_params}."
          # }
        end

        # Perform work. Used by Resque.
        # @param [Hash] harvest_params
        # @return [Array<Hash>] array of hashes representing operations performed
        def perform(harvest_params)


        end

      end
    end
  end
end