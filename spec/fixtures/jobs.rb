# frozen_string_literal: true

module Fixtures
  FIXTURE_QUEUE = :default_test

  class FixtureJob < BawWorkers::Jobs::ApplicationJob
    queue_as FIXTURE_QUEUE
    perform_expects String

    def name
      @name ||= job_id
    end

    def create_job_id
      "#{self.class.name}:#{arguments[0]}"
    end
  end

  class BasicJob < FixtureJob
    def perform(_echo_id)
      'i just work'
    end
  end

  class RetryableJob < FixtureJob
    ATTEMPTS = 3
    def perform(_echo_id)
      tick("tick #{executions}/#{ATTEMPTS}")

      return if executions >= ATTEMPTS

      raise BawWorkers::Jobs::IntentionalRetry
    end

    retry_on BawWorkers::Jobs::IntentionalRetry, wait: 1, attempts: ATTEMPTS
  end

  class WorkingJob < FixtureJob
    perform_expects String, Integer
    #
    # Does the work
    #
    # @param [String] _echo_id a job name
    # @param [Integer] repeats The number of times to tick
    #
    # @return [void]
    #
    def perform(_echo_id, repeats)
      (1..repeats).each do |num|
        report_progress(num, repeats, "At #{num}")
      end
    end
  end

  class ErrorJob < FixtureJob
    #
    # Does the work
    #
    # @param [String] _echo_id a job name
    #
    # @return [void] Always throws
    #
    def perform(_echo_id)
      raise "I'm a bad little job"
    end

    def on_errored(error)
      push_message("on error called: #{error.message}")
    end
  end

  class DiscardJob < FixtureJob
    # the error could happen before our handlers are registered
    before_perform do
      @status = nil
    end

    #
    # Does the work
    #
    # @param [String] _echo_id a job name
    #
    # @return [void] Always throws
    #
    def perform(_echo_id)
      raise ArgumentError, 'should be discarded'
    end

    discard_on ArgumentError
  end

  class KillableJob < FixtureJob
    def perform(_echo_id)
      logger.info { 'starting killable ' }
      (0..100).each do |num|
        logger.info('progress killable ', num: num)
        report_progress(num, 100, "At #{num} of 100")
        sleep(0.1)
      end
    end

    def on_killed
      push_message('on kill called')
    end
  end

  class FailureJob < FixtureJob
    def perform(_echo_id)
      failed!("I'm such a failure")
    end

    def on_failure
      push_message('on failure called')
    end
  end

  class CompletedJob < FixtureJob
    def perform(_echo_id)
      completed!("I'm such a completionist")
    end

    def on_completed
      push_message('on completed called')
    end
  end

  class NeverQueuedJob < FixtureJob
    before_enqueue do
      throw :abort
    end

    def perform(echo_id)
      # will never get called
    end
  end

  class DuplicateJob < FixtureJob
    perform_expects String, Integer

    def perform(_echo_id, _sanity_id)
      'i am a job'
    end

    def name
      @name ||= job_id + "(Copy #{arguments[1]})"
    end
  end

  class FakeAnalysisJob < BawWorkers::Jobs::ApplicationJob
    queue_as Settings.actions.analysis.queue
    perform_expects Hash

    def perform(analysis_params)
      status_updater = BawWorkers::Jobs::Analysis::Status.new(BawWorkers::Config.api_communicator)
      mock_result = analysis_params[:mock_result]&.to_sym || :successful
      skip_completion = analysis_params[:skip_completion] == true
      good_cancel_behaviour = analysis_params.fetch(:good_cancel_behaviour, true) == true

      # do the working status update call
      begin
        # check if should cancel
        status_updater.begin(analysis_params)
      rescue BawWorkers::Exceptions::ActionCancelledError
        status_updater.end(analysis_params, :cancelled) if good_cancel_behaviour
        return
      end

      duration = analysis_params.fetch(:sleep, 0.0)
      BawWorkers::Config.logger_worker.info('sleep for', sleep: duration)
      sleep duration

      # do some work
      work = {
        resque_id: job_id,
        analysis_params: analysis_params,
        result: Time.now
      }

      unless skip_completion
        # simulate the complete call
        status_updater.end(analysis_params, mock_result)

        raise 'Fake analysis job failing on purpose' if mock_result == :failed
      end

      work
    end

    def create_job_id
      # duplicate jobs should be detected
      ::BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(self, 'fake_analysis_job')
    end

    def name
      job_id
    end
  end
end
