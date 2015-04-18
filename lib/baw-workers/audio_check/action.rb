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
          BawWorkers::Settings.actions.audio_check.queue
        end

        # Perform check on a single audio file. Used by Resque.
        # @param [Hash] audio_params
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_perform(audio_params)
          action_run(audio_params, true)
        end

        # Run the job.
        # @param [Hash] audio_params
        # @param [Boolean] is_real_run
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_run(audio_params, is_real_run)

          BawWorkers::Config.logger_worker.info(self.name) {
            "Started audio check #{is_real_run ? 'real run' : 'dry run' } using '#{audio_params}'."
          }

          begin
            result = action_audio_check.run(audio_params, is_real_run)
          rescue Exception => e
            BawWorkers::Config.logger_worker.error(self.name) { e }
            # don't send emails, we will use logs.
            # BawWorkers::Mail::Mailer.send_worker_error_email(
            #     BawWorkers::AudioCheck::Action,
            #     audio_params,
            #     queue,
            #     e
            # )
            raise e
          end

          BawWorkers::Config.logger_worker.info(self.name) {
            "Completed audio check with result '#{result}'."
          }

          result
        end

        # Perform check on multiple audio files from a csv file.
        # @param [String] csv_file
        # @param [Boolean] is_real_run
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_perform_rake(csv_file, is_real_run)
          BawWorkers::Validation.validate_file(csv_file)

          successes = []
          failures = []
          BawWorkers::AudioCheck::CsvHelper.read_audio_recording_csv(csv_file) do |audio_params|
            begin
              result = BawWorkers::AudioCheck::Action.action_run(audio_params, is_real_run)
              successes.push({params: audio_params, result: result})
            rescue Exception => e
              failures.push({params: audio_params, exception: e})
            end
          end

          {
              successes: successes,
              failures: failures
          }
        end

        # Enqueue an audio file check request.
        # @param [Hash] audio_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue(audio_params)
          audio_params_sym = BawWorkers::AudioCheck::WorkHelper.validate(audio_params)
          #result = Resque.enqueue(BawWorkers::AudioCheck::Action, audio_params_sym)
          result = BawWorkers::AudioCheck::Action.create(audio_params: audio_params_sym)
          BawWorkers::Config.logger_worker.info(self.name) {
            "Job enqueue returned '#{result}' using #{audio_params}."
          }
          result
        end

        # Enqueue multiple audio file check requests from a csv file.
        # @param [String] csv_file
        # @param [Boolean] is_real_run
        # @return [Hash]
        def action_enqueue_rake(csv_file, is_real_run)
          BawWorkers::Validation.validate_file(csv_file)

          successes = []
          failures = []
          BawWorkers::AudioCheck::CsvHelper.read_audio_recording_csv(csv_file) do |audio_params|
            begin
              result = nil
              result = BawWorkers::AudioCheck::Action.action_enqueue(audio_params) if is_real_run
              successes.push({params: audio_params, result: result})
            rescue Exception => e
              failures.push({params: audio_params, exception: e})
            end
          end

          {
              successes: successes,
              failures: failures
          }
        end

        def action_audio_check
          BawWorkers::AudioCheck::WorkHelper.new(
              BawWorkers::Config.logger_worker,
              BawWorkers::Config.file_info,
              BawWorkers::Config.api_communicator)
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