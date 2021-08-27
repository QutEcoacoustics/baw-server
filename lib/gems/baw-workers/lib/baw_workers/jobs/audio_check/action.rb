# frozen_string_literal: true

module BawWorkers
  module Jobs
    module AudioCheck
      # Runs checks on original audio recording files.
      class Action < BawWorkers::Jobs::ApplicationJob
        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        queue_as Settings.actions.audio_check.queue
        perform_expects Hash

        # Perform check on a single audio file. Used by Resque.
        # @param [Hash] audio_params
        # @return [Array<Hash>] array of hashes representing operations performed
        def perform(audio_params)
          action_run(audio_params, true)
        end

        # Run the job.
        # @param [Hash] audio_params
        # @param [Boolean] is_real_run
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_run(audio_params, is_real_run)
          BawWorkers::Config.logger_worker.info(name) do
            "Started audio check #{is_real_run ? 'real run' : 'dry run'} using '#{audio_params}'."
          end

          begin
            result = action_audio_check.run(audio_params, is_real_run)
          rescue StandardError => e
            BawWorkers::Config.logger_worker.error(name) { e }
            # don't send emails, we will use logs.
            # BawWorkers::Mail::Mailer.send_worker_error_email(
            #     BawWorkers::Jobs::AudioCheck::Action,
            #     audio_params,
            #     queue,
            #     e
            # )
            raise
          end

          BawWorkers::Config.logger_worker.info(name) do
            "Completed audio check with result '#{result}'."
          end

          result
        end

        # Enqueue an audio file check request.
        # @param [Hash] audio_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def self.action_enqueue(audio_params)
          audio_params_sym = BawWorkers::Jobs::AudioCheck::WorkHelper.validate(audio_params)

          job = BawWorkers::Jobs::AudioCheck::Action.new({ audio_params: audio_params_sym })

          result = job.enqueue != false
          BawWorkers::Config.logger_worker.info(name) do
            "Job enqueue returned '#{result}' using #{audio_params}."
          end

          job.job_id
        end

        def action_audio_check
          BawWorkers::Jobs::AudioCheck::WorkHelper.new(
            BawWorkers::Config.logger_worker,
            BawWorkers::Config.file_info,
            BawWorkers::Config.api_communicator
          )
        end

        def create_job_id
          # duplicate jobs should be detected
          ::BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(self, 'analysis_job')
        end

        # Produces a sensible name for this payload.
        # Should be unique but does not need to be. Has no operational effect.
        # This value is only used when the status is updated by status.
        def name
          job_id
        end
      end
    end
  end
end
