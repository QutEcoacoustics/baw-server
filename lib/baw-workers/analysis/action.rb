module BawWorkers
  module Analysis
    # Runs analysis scripts on audio files.
    class Action

      # Ensure that there is only one job with the same payload per queue.
      include Resque::Plugins::UniqueJob

      # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
      extend Resque::Plugins::JobStats

      # track specific job instances and their status
      include Resque::Plugins::Status

      # include common methods
      # must be the last include/extend so it can override methods
      include BawWorkers::ActionCommon

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
          BawWorkers::Settings.actions.analysis.queue
        end

        # Get logger
        def action_logger
          BawWorkers::Settings.logger
        end

        # Perform work. Used by resque.
        # @param [Hash] analysis_params
        def action_perform(analysis_params)
          begin
            # todo
          rescue Exception => e
            BawWorkers::Settings.logger.error(self.name) { e }
            raise e
          end
        end

        # Enqueue an analysis request.
        # @param [Hash] analysis_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue(analysis_params)
          result = BawWorkers::Media::Action.create(analysis_params: analysis_params)
          BawWorkers::Settings.logger.info(self.name) {
            "Job enqueue returned '#{result}' using type #{media_type} with #{analysis_params}."
          }
        end

      end

      # Perform method used by resque-status.
      def perform
        analysis_params = options['analysis_params']
        self.class.action_perform(analysis_params)
      end

    end
  end
end