module BawWorkers
  module Action
    # Runs checks on original audio recording files.
    class AudioFileCheckAction

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

        # Get the queue for this action. Used by `resque`.
        # @return [Symbol] The queue.
        def queue
          BawWorkers::Settings.resque.queues.maintenance
        end

        # Enqueue an audio file check request.
        # @param [Hash] audio_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def enqueue(audio_params)
          audio_params_sym = AudioFileCheck.validate(audio_params)
          result = Resque.enqueue(AudioFileCheckAction, audio_params_sym)
          BawWorkers::Settings.logger.info(self.name) {
            "Enqueued from AudioFileCheckAction. Resque enqueue returned #{result} using #{audio_params}."
          }
        end

        # Perform work. Used by `resque`.
        # @param [Hash] audio_params
        # @return [Array<Hash>] array of hashes representing operations performed
        def perform(audio_params)
          audio_file_check = AudioFileCheck.new(BawWorkers::Settings.logger, BawWorkers::Settings.resque.dry_run)

          begin
            audio_file_check.run(audio_params)
          rescue Exception => e
            BawWorkers::Settings.logger.error(self.name) { e }
            raise
          end

        end

      end
    end
  end
end