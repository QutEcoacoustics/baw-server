module BawWorkers
  module Analysis
    # Runs analysis scripts on audio files.
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
          BawWorkers::Settings.resque.queues.analysis
        end

        # Enqueue an analysis request.
        # @param [Hash] analysis_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def enqueue(analysis_params)
          # audio_params_sym = BawWorkers::AudioCheck::Process.validate(audio_params)
          # result = Resque.enqueue(BawWorkers::AudioCheck::Action, audio_params_sym)
          # BawWorkers::Settings.logger.info(self.name) {
          #   "Enqueued from AudioFileCheckAction. Resque enqueue returned #{result} using #{audio_params}."
          # }
        end

        # Perform work. Used by resque.
        # @param [Hash] analysis_params
        def perform(analysis_params)
          # audio_file_check = BawWorkers::AudioCheck::Process.new(BawWorkers::Settings.logger, BawWorkers::Settings.resque.dry_run)
          #
          # begin
          #   audio_file_check.run(audio_params)
          # rescue Exception => e
          #   BawWorkers::Settings.logger.error(self.name) { e }
          #   raise e
          # end

        end

      end
    end
  end
end