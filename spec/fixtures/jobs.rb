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
end
