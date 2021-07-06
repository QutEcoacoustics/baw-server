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
            raise e
          end

          BawWorkers::Config.logger_worker.info(name) do
            "Completed audio check with result '#{result}'."
          end

          result
        end

        # Perform check on multiple audio files from a csv file.
        # @param [String] csv_file
        # @param [Boolean] is_real_run
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_perform_rake(csv_file, is_real_run)
          BawWorkers::Validation.normalise_file(csv_file)

          successes = []
          failures = []
          BawWorkers::ReadCsv.read_audio_recording_csv(csv_file) do |audio_params|
            result = BawWorkers::Jobs::AudioCheck::Action.action_run(audio_params, is_real_run)
            successes.push({ params: audio_params, result: result })
          rescue StandardError => e
            failures.push({ params: audio_params, exception: e })
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
          audio_params_sym = BawWorkers::Jobs::AudioCheck::WorkHelper.validate(audio_params)
          #result = Resque.enqueue(BawWorkers::Jobs::AudioCheck::Action, audio_params_sym)
          result = BawWorkers::Jobs::AudioCheck::Action.perform_later!({ audio_params: audio_params_sym })
          BawWorkers::Config.logger_worker.info(name) do
            "Job enqueue returned '#{result}' using #{audio_params}."
          end
          result
        end

        # Enqueue multiple audio file check requests from a csv file.
        # @param [String] csv_file
        # @param [Boolean] is_real_run
        # @return [Hash]
        def action_enqueue_rake(csv_file, is_real_run)
          BawWorkers::Validation.normalise_file(csv_file)

          successes = []
          failures = []
          BawWorkers::ReadCsv.read_audio_recording_csv(csv_file) do |audio_params|
            result = nil
            result = BawWorkers::Jobs::AudioCheck::Action.perform_later!(audio_params) if is_real_run
            successes.push({ params: audio_params, result: result })
          rescue StandardError => e
            failures.push({ params: audio_params, exception: e })
          end

          results = {
            successes: successes,
            failures: failures
          }

          BawWorkers::Config.logger_worker.info(name) do
            msg1 = is_real_run ? 'Enqueued jobs.' : 'Dry run without enqueuing jobs.'
            msg2 = "#{successes.size} jobs successful and #{failures.size} jobs failed"
            "#{msg1} #{msg2}: #{results}"
          end

          results
        end

        def action_audio_check
          BawWorkers::Jobs::AudioCheck::WorkHelper.new(
            BawWorkers::Config.logger_worker,
            BawWorkers::Config.file_info,
            BawWorkers::Config.api_communicator
          )
        end

        def perform_options_keys
          ['audio_params']
        end
      end
    end
  end
end
