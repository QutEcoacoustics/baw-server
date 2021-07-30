# frozen_string_literal: true

module ResqueHelpers
  module Emulate
    module_function

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
    # @!attribute [r] get_pause_test_jobs
    #   @return [Boolean]
    # @!method set_pause_test_jobs
    #   @param [Boolean] value
    #   @return [void]

    # Pause resque jobs in the test environment until they are manually triggered
    # by ResqueHelper::Example.perform_jobs.
    def pause_all_jobs
      set_pause_test_jobs(true, caller)
    end

    # Do not pause any resque jobs in the test environment. In other words,
    # run the resque worker normally.
    def perform_all_jobs_normally
      set_pause_test_jobs(false, caller)
    end

    # Temporarily change the resque logger level for the duration of the test
    # @param [Symbol,Logger::Severity,Integer] level the log level to use
    def resque_log_level(level)
      around do |example|
        original = Resque.logger.level
        Resque.logger.level = level
        example.run
        Resque.logger.level = original
      end
    end

    #
    #  do not throw an error if there are outstanding jobs left in the queue
    # @!attribute [r] get_ignore_leftover_jobs
    #   @return [Boolean]
    # @!method set_ignore_leftover_jobs
    #   @param [Boolean] value
    #   @return [void]

    def ignore_pending_jobs
      set_ignore_leftover_jobs(true, caller)
      logger.info 'will ignore leftovers', class: name
    end

    # RSpec hooks are only available once this module has been extended into RSpec::Core::ExampleGroup
    def self.extended(example_group)
      example_group.define_metadata_state :pause_test_jobs, default: false
      example_group.define_metadata_state :ignore_leftover_jobs, default: false

      example_group.before do
        # Disable the inbuilt test adapter for every test!
        # https://github.com/rails/rails/issues/37270
        (ActiveJob::Base.descendants << ActiveJob::Base).each do |klass|
          klass.disable_test_adapter if defined?(klass.disable_test_adapter)
        end
        ActiveJob::Base.queue_adapter = :resque

        logger.info(trace_metadata(:pause_test_jobs))
        BawWorkers::ResquePatch::PauseDequeueForTests.set_paused(get_pause_test_jobs)
      end

      example_group.after do
        remaining = BawWorkers::ResqueApi.queued_count
        next if remaining.zero?

        logger.info(trace_metadata(:ignore_leftover_jobs))
        raise "There are #{remaining} uncompleted jobs for this spec" unless get_ignore_leftover_jobs

        logger.warn "#{remaining} jobs are still in the queue, ignored intentionally by ignore_pending_jobs"
      end
    end
  end

  # Helper methods that deal with resque that are available inside
  # of an example. Can use in `it`/`example` blocks.
  # This module should be included into an example group.
  module Example
    #include BawWorkers::ResqueApi

    PERFORMED_KEYS = BawWorkers::ActiveJob::Status::TERMINAL_STATUSES

    def clear_pending_jobs
      BawWorkers::ResqueApi.clear_queues
    end

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
    # @param [Class] of_class - of which class we expected enqueued jobs to be. Defaults to `nil` which matches any class.
    # @return [Array<Hash>]
    def expect_enqueued_jobs(count, klass: nil, of_class: nil)
      of_class ||= klass
      jobs = if of_class.nil?
               BawWorkers::ResqueApi.jobs_queued
             else
               BawWorkers::ResqueApi.jobs_queued_of(of_class)
             end

      aggregate_failures do
        expect(jobs).to be_a(Array)
        expect(jobs).to have(count).items
      end
      jobs
    end

    def expect_delayed_jobs(count)
      expect(count).to eq BawWorkers::ResqueApi.delayed_count
    end

    # Expects the completed, failed, and enqueued counts of jobs to be of a certain size.
    # @param [Integer] completed - the count of completed jobs we expect
    # @param [Integer] failed - the count of failed jobs we expect, defaults to 0
    # @param [Integer] enqueued - the count of enqueued jobs we expect, defaults to 0
    # @param [Class] klass - of which class we expected completed jobs to be. Defaults to `nil` which matches any class.
    def expect_jobs_to_be(completed:, failed: 0, enqueued: 0, klass: nil)
      actual_completed = BawWorkers::ResqueApi.statuses(statuses: BawWorkers::ActiveJob::Status::STATUS_COMPLETED,
                                                        klass: klass)
      actual_failed = BawWorkers::ResqueApi.failed
      actual_enqueued = BawWorkers::ResqueApi.jobs_queued
      aggregate_failures do
        expect(actual_completed).to be_a(Array)
        expect(actual_failed).to be_a(Array)
        expect(actual_enqueued).to be_a(Array)
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

      original_pause_value = BawWorkers::ResquePatch::PauseDequeueForTests.paused?
      BawWorkers::ResquePatch::PauseDequeueForTests.set_paused(false)

      yield

      BawWorkers::ResquePatch::PauseDequeueForTests.set_paused(original_pause_value)
    end

    #
    # Uses the Redis MONITOR command to monitor commands sent to redis while running
    # a user supplied block
    # @param [#<<] io - any object that supports the `<<` operator to append messages to.
    # @return [Array<String>] The commands that were recorded
    #
    def monitor_redis(io: nil, &block)
      connection_settings = Settings.redis.connection.to_h.freeze
      lock = Concurrent::Semaphore.new(1)
      lock.acquire
      r = Concurrent::Promises.future(connection_settings) { |cs|
        redis = Redis.new(cs)
        messages = []
        catch(:stop) do
          redis.monitor do |msg|
            messages << msg
            io << msg << "\n" unless io.nil?
            throw :stop if lock.try_acquire
          end
        end

        messages
      }
      begin
        block.call
      ensure
        lock.release
      end

      r.value!
    end

    # Perform a number of jobs and **BLOCK** execution until the jobs are completed.
    # Set a flag in redis that the Test worker listens for.
    # That worker will then complete the given number of jobs.
    # @param [Integer,nil] count the number of jobs to perform. Use `nil` to indicate that all enqueued jobs should be performed.
    # @param [Float] timeout the amount of time to wait for a job to finish
    # @return [Array<BawWorkers::ActiveJob::Status::StatusData>] an array of job statuses that were performed.
    def perform_jobs(count: nil, timeout: 30)
      stats = job_stats
      existing = stats[:statuses].count
      count = stats[:total_pending] if count.nil?

      if stats[:total_pending] < count
        logger.warn("Can't perform #{count} jobs because there are only #{stats[:total_pending]} jobs in the queue")
      end

      logger.info "Performing #{count} jobs..."
      started = Time.now

      expect(BawWorkers::ResquePatch::PauseDequeueForTests.set_perform_count(count)).to eq 'OK'

      statuses = []
      elapsed = 0
      error = loop {
        now = Time.now
        elapsed = now - started
        break 'Timed out waiting for jobs to finish' if elapsed > timeout

        job_stats => { statuses:, **stats }

        logger.info('Waiting for test jobs to be performed', { existing_statuses: existing, **stats })
        break if (stats[:status_execution_count] - existing) >= count

        sleep(0.5)
      }

      unless error.blank?
        details = BawWorkers::ResqueApi.failed.reduce('') { |message, failed| "#{message}\n#{failed}" }
        raise "#{error}\nFailures that occurred while waiting: #{details}\nStatuses received #{statuses}"
      end

      logger.info("Waiting completed,in #{elapsed} seconds", stats)
      statuses
    end

    def job_stats
      enqueued = BawWorkers::ResqueApi.queued_count
      delayed = BawWorkers::ResqueApi.delayed_count
      statuses = BawWorkers::ResqueApi.statuses(statuses: PERFORMED_KEYS)
      {
        enqueued: enqueued,
        delayed: delayed,
        total_pending: enqueued + delayed,
        statuses: statuses,
        status_execution_count: statuses.sum { |s| (s&.options&.fetch(:executions, nil) || 0) + 1 }
      }
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
