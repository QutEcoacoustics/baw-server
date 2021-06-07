# frozen_string_literal: true

module ResqueHelpers
  module Emulate
    extend self

    def resque_worker_with_job(job_class, job_args, opts = {})
      # see http://stackoverflow.com/questions/5141378/how-to-bridge-the-testing-using-resque-with-rspec-examples
      queue = opts[:queue] || 'test_queue'

      Resque::Job.create(queue, job_class, *job_args)

      ResqueHelpers::Emulate.resque_worker(queue, opts[:verbose], opts[:fork])
    end

    # from https://github.com/resque/resque/blob/1-x-stable/test/test_helper.rb
    def without_forking
      orig_fork_per_job = ENV['FORK_PER_JOB']
      begin
        ENV['FORK_PER_JOB'] = 'false'
        yield
      ensure
        ENV['FORK_PER_JOB'] = orig_fork_per_job
      end
    end

    # Emulate a resque worker
    # @param [String] queue
    # @param [Boolean] verbose
    # @param [Boolean] fork
    # @return [Array] worker, job
    # @param [String] override_class - specify to switch what type actually processes the payload at the last minute. Useful for testing.
    def resque_worker(queue, verbose, fork, override_class = nil)
      queue ||= 'test_queue'

      worker = Resque::Worker.new(queue)
      worker.very_verbose = true if verbose

      job = nil

      if fork
        # do a single job then shutdown
        def worker.done_working
          super
          shutdown
        end

        # can't fork during tests
        without_forking do
          # start worker working, using interval of 0.5 seconds
          # see Resque::Worker#work
          worker.work(0.5) do |worker_job|
            job = worker_job
          end
        end

      else
        job = worker.reserve

        unless job.nil?
          job.payload['class'] = override_class if override_class
          finished_job = worker.perform(job)
          job = finished_job
        end
      end

      [worker, job]
    end
  end

  # Helper methods that deal with resque that are available outside
  # of an example. Can use in `describe`/`context` blocks.
  # This module should be extended into an example group.
  module ExampleGroup
    # Whether or not to pause test jobs
    # @return [Boolean]
    @pause_test_jobs

    # Pause resque jobs in the test environment until they are manually triggered
    # by ResqueHelper::Example.perform_jobs.
    def pause_all_jobs
      @pause_test_jobs = true
    end

    # Do not pause any resque jobs in the test environment. In other words,
    # run the resque worker normally.
    def perform_all_jobs_normally
      @pause_test_jobs = false
    end

    # Whether or not to pause test jobs
    # @return [Boolean]
    def pause_test_jobs?
      # pause jobs by default
      true if @pause_test_jobs.nil?
      !!@pause_test_jobs
    end

    # Temporarily change the resque logger level for the duration of the test
    # @param [Symbol|Logger::Severity|Integer] level the log level to use
    def resque_log_level(level)
      around(:each) do |example|
        original = Resque.logger.level
        Resque.logger.level = level
        example.run
        Resque.logger.level = original
      end
    end

    # RSpec hooks are only available once this module has been extended into RSpec::Core::ExampleGroup
    def self.extended(example_group)
      example_group.before(:each) do
        # Disable the inbuilt test adapter for every test!
        # https://github.com/rails/rails/issues/37270
        (ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)
        ActiveJob::Base.queue_adapter = :resque

        Resque::Plugins::PauseDequeueForTests.set_paused(example_group.pause_test_jobs?)
      end

      example_group.after(:each) do
        raise 'There are uncompleted jobs for this spec' if BawWorkers::ResqueApi.queued_count > 0
      end
    end
  end

  # Helper methods that deal with resque that are available inside
  # of an example. Can use in `it`/`example` blocks.
  # This module should be included into an example group.
  module Example
    include BawWorkers::ResqueApi

    PERFORMED_KEYS = [
      BawWorkers::ActiveJob::Status::STATUS_COMPLETED,
      BawWorkers::ActiveJob::Status::STATUS_FAILED,
      BawWorkers::ActiveJob::Status::STATUS_KILLED
    ].freeze

    # Expects the completed job statuses to be of a certain size. Includes completed, failed, and killed jobs.
    # @param [Integer] count - the count of job statuses we expect
    # @param [Class] klass - of which class we expected the job statuses jobs to be. Defaults to `nil` which matches any class.
    # @return [Array<BawWorkers::ActiveJob::Status::StatusData>]
    def expect_performed_jobs(count, klass: nil)
      statuses = BawWorkers::ResqueApi.statuses(statuses: PERFORMED_KEYS, klass: klass)

      expect(statuses).to be_a(Array)
      expect(statuses).to have(count).items

      statuses
    end

    # Expects the failed queues to be of a certain size.
    # @param [Integer] count - the count of failed jobs we expect
    # @param [Class] klass - of which class we expected failed jobs to be. Defaults to `nil` which matches any class.
    # @return [Array<Resque::Failure>]
    def expect_failed_jobs(count, klass: nil)
      failures = BawWorkers::ResqueApi.failed(klass: klass)

      expect(statuses).to be_a(Array)
      expect(failures).to have(count).items

      failures
    end

    # Expects the enqueued queues to be of a certain size.
    # @param [Integer] count - the count of enqueued jobs we expect
    # @param [Class] klass - of which class we expected enqueued jobs to be. Defaults to `nil` which matches any class.
    # @return [Array<Hash>]
    def expect_enqueued_jobs(count, klass: nil)
      jobs = if klass.nil?
               BawWorkers::ResqueApi.jobs_queued
             else
               BawWorkers::ResqueApi.jobs_queued_of(klass)
             end

      expect(statuses).to be_a(Array)
      expect(jobs).to have(count).items

      jobs
    end

    # Expects the completed, failed, and enqueued counts of jobs to be of a certain size.
    # @param [Integer] completed - the count of completed jobs we expect
    # @param [Integer] failed - the count of failed jobs we expect, defaults to 0
    # @param [Integer] enqueued - the count of enqueued jobs we expect, defaults to 0
    # @param [Class] klass - of which class we expected completed jobs to be. Defaults to `nil` which matches any class.
    def expect_jobs_to_be(completed:, failed: 0, enqueued: 0, klass: nil)
      actual_completed = BawWorkers::ResqueApi.statuses(statuses: BawWorkers::ActiveJob::Status::STATUS_COMPLETED, klass: klass)
      actual_failed = BawWorkers::ResqueApi.failed
      actual_enqueued = BawWorkers::ResqueApi.jobs_queued
      aggregate_failures do
        expect([actual_completed, actual_failed, actual_enqueued]).to all(be_a(Array))
        expect(actual_completed).to have(completed).items
        expect(actual_failed).to have(failed).items
        expect(actual_enqueued).to have(enqueued).items
      end
    end

    # Run all jobs as soon as they're enqueued, reverting settings when the given block has finished.
    # Will NOT block for job completion!
    # Must be supplied with a block.
    # Intended for use in an RSpec around hook.
    # @example
    #   around(:each) do |example|
    #     perform_all_jobs_immediately do
    #       example.run
    #     end
    #   end
    def perform_all_jobs_immediately
      raise ArgumentError, 'A block must be given to `perform_all_jobs_immediately`' unless block_given?

      original_pause_value = Resque::Plugins::PauseDequeueForTests.paused?
      Resque::Plugins::PauseDequeueForTests.set_paused(false)

      yield

      Resque::Plugins::PauseDequeueForTests.set_paused(original_pause_value)
    end

    # Perform a number of jobs and **BLOCK** execution until the jobs are completed.
    # Set a flag in redis that the Test worker listens for.
    # That worker will then complete the given number of jobs.
    # @param [Integer|nil] count the number of jobs to perform. Use `nil` to indicate that all enqueued jobs should be performed.
    # @return [Array<BawWorkers::ActiveJob::Status::Hash>] an array of job statuses that were performed.
    def perform_jobs(count: nil)
      enqueued = BawWorkers::ResqueApi.queued_count
      count = enqueued if count.nil?

      if enqueued < count
        raise ArgumentError, "Can't perform #{count} jobs because there are only #{enqueued} jobs in the queue"
      end

      logger.info "Performing #{count} jobs..."
      started = Time.now

      expect(Resque::Plugins::PauseDequeueForTests.set_perform_count(count)).to eq 'OK'

      performed = []
      elapsed = 0
      error = loop {
        now = Time.now
        elapsed = now - started
        break 'Timed out waiting for jobs to finish' if elapsed > 30.0

        performed = BawWorkers::ResqueApi.statuses(statuses: PERFORMED_KEYS, range_start: started, range_end: now)

        logger.info("Waiting for test jobs to be performed, #{performed.count} jobs of #{count} have been performed...")
        break if performed.size >= count

        sleep(0.5)
      }

      unless error.blank?
        details = BawWorkers::ResqueApi.failed.reduce('') { |message, failed| message + "\n" + failed.to_s }
        raise "#{error}\nFailures that occurred while waiting: #{details}"
      end

      logger.info("Waiting completed, performed #{performed.count} jobs in #{elapsed} seconds")
      performed
    end
  end
end

class FakeJob
  def self.perform(*job_args)
    {
      job_args: job_args,
      result: Time.now
    }
  end
end
