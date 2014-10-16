module BawWorkers
  module AudioCheck
    # Runs checks on original audio recording files.
    class Action

      # Ensure that there is only one job with the same payload per queue.
      include Resque::Plugins::UniqueJob

      # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
      extend Resque::Plugins::JobStats

      # track specific job instances and their status
      include Resque::Plugins::Status

      # include common methods
      include BawWorkers::Common

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
          BawWorkers::Settings.resque.queues.maintenance
        end

        # Get logger
        def action_logger
          BawWorkers::Settings.logger
        end

        def action_api
          api_comm = BawWorkers::ApiCommunicator.new(
              action_logger,
              BawWorkers::Settings.api,
              BawWorkers::Settings.endpoints)
        end

        def action_file_info
          BawWorkers::FileInfo.new(
              action_logger,
              BawWorkers::Settings.audio_helper
          )
        end

        def action_audio_check
          BawWorkers::AudioCheck::WorkHelper.new(
              BawWorkers::Settings.logger,
              action_file_info,
              action_api)
        end

        # Perform work. Used by Resque.
        # @param [Hash] audio_params
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_perform(audio_params)
          audio_file_check = action_audio_check

          begin
            audio_file_check.run(audio_params, BawWorkers::Settings.resque.dry_run)
          rescue Exception => e
            BawWorkers::Settings.logger.error(self.name) { e }
            raise e
          end

        end

        # Enqueue an audio file check request.
        # @param [Hash] audio_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue(audio_params)
          audio_params_sym = BawWorkers::AudioCheck::WorkHelper.validate(audio_params)
          #result = Resque.enqueue(BawWorkers::AudioCheck::Action, audio_params_sym)
          result = BawWorkers::Media::Action.create(audio_params: audio_params_sym)
          BawWorkers::Settings.logger.info(self.name) {
            "Job enqueue returned '#{result}' using #{audio_params}."
          }
        end



      end

      # Perform method used by resque-status.
      def perform
        audio_params = options['audio_params']
        self.class.action_perform(audio_params)
      end

    end
  end
end