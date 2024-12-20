# frozen_string_literal: true

module ResqueHelpers
  module Emulate
    @logger = SemanticLogger[ResqueHelpers::Emulate]

    module_function

    def resque_worker_with_job(job_class, job_args, opts = {})
      # see http://stackoverflow.com/questions/5141378/how-to-bridge-the-testing-using-resque-with-rspec-examples
      queue = opts[:queue] || 'test_queue'

      Resque::Job.create(queue, job_class, *job_args)

      ResqueHelpers::Emulate.resque_worker(queue, opts[:verbose], opts[:fork])
    end

    # from https://github.com/resque/resque/blob/1-x-stable/test/test_helper.rb
    def without_forking
      orig_fork_per_job = ENV.fetch('FORK_PER_JOB', nil)
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
    # @param [String,nil] override_class - specify to switch what type actually
    #   processes the payload at the last minute. Useful for testing.
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
        #without_forking do
        # start worker working, using interval of 0.5 seconds
        # see Resque::Worker#work
        @logger.info('Waiting for job in process', job:)
        worker.work(0)
        # do |worker_job|
        #   job = worker_job
        # end
        #end

      else
        job = worker.reserve

        unless job.nil?
          job.payload['class'] = override_class if override_class
          @logger.info('Performing job in process', job:)
          finished_job = worker.perform(job)
          job = finished_job

          ActiveRecord::Base.connection_pool.release_connection
          ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
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
        logger.info(trace_metadata(:pause_test_jobs))
        BawWorkers::ResquePatch::PauseDequeueForTests.set_paused(get_pause_test_jobs)

        # NOTE: we disable recurring jobs by default on our test scheduler
        # because extra enqueued jobs while other tests are running would break
        # so many things.
        logger.info('Clearing all recurring schedules')
        BawWorkers::ResqueApi.clear_all_schedules
      end

      example_group.after do |example|
        # NOTE: we disable recurring jobs by default on our test scheduler
        # because extra enqueued jobs while other tests are running would break
        # so many things.
        logger.info('Clearing all recurring schedules')
        BawWorkers::ResqueApi.clear_all_schedules

        remaining = BawWorkers::ResqueApi.queued_count
        next if remaining.zero?

        logger.info(trace_metadata(:ignore_leftover_jobs))
        unless get_ignore_leftover_jobs
          spec_info = example.location
          other_jobs = BawWorkers::ResqueApi.job_count_by_class
          raise "There are #{remaining} uncompleted jobs for this spec: #{spec_info}\n#{other_jobs}"
        end

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

    def expect_queue_count(queue_name, count)
      expect(Resque.size(queue_name)).to eq count
    end

    def expect_failed_queue_count(count)
      expect(Resque::Failure.count).to eq count
    end

    # Expects the completed job statuses to be of a certain size. Includes completed, failed, and killed jobs.
    # @param [Integer] count - the count of job statuses we expect
    # @param [Class] of_class - of which class we expected the job statuses jobs to be. Defaults to `nil` which matches any class.
    # @return [Array<BawWorkers::ActiveJob::Status::StatusData>]
    def expect_performed_jobs(count, klass: nil, of_class: nil)
      of_class ||= klass
      statuses = BawWorkers::ResqueApi.statuses(statuses: PERFORMED_KEYS, klass: of_class)

      expect(statuses).to be_a(Array).and(have_attributes(count:))
      statuses
    end

    # Expects the failed queues to be of a certain size.
    # @param [Integer] count - the count of failed jobs we expect
    # @param [Class] klass - of which class we expected failed jobs to be. Defaults to `nil` which matches any class.
    # @return [Array<Resque::Failure>]
    def expect_failed_jobs(count, klass: nil)
      failures = BawWorkers::ResqueApi.failed(klass:)

      expect(failures).to be_a(Array).and(have_attributes(count:))

      failures
    end

    # Expects the enqueued queues to be of a certain size.
    # @param [Integer] count - the count of enqueued jobs we expect
    # @param [Class] of_class - of which class we expected enqueued jobs to be. Defaults to `nil` which matches any class.
    # @return [Array<Hash>]
    def expect_enqueued_jobs(count, klass: nil, of_class: nil)
      of_class ||= klass
      queued = if of_class.nil?
                 BawWorkers::ResqueApi.jobs_queued
               else
                 BawWorkers::ResqueApi.jobs_queued_of(of_class)
               end

      aggregate_failures do
        expect(queued).to be_a(Array)
        expect(queued).to(
          have(count).items,
          "expected array with count #{count}, but got #{queued.size} with items: #{queued.inspect}"
        )
      end
      queued
    end

    def expect_delayed_jobs(count)
      expect(count).to eq BawWorkers::ResqueApi.delayed_count
    end

    # Expects the completed, failed, and enqueued counts of jobs to be of a certain size.
    # @param [Integer] completed - the count of completed jobs we expect
    # @param [Integer] failed - the count of failed jobs we expect, defaults to 0
    # @param [Integer] enqueued - the count of enqueued jobs we expect, defaults to 0
    # @param [Class] of_class - of which class we expected completed jobs to be. Defaults to `nil` which matches any class.
    def expect_jobs_to_be(completed:, failed: 0, enqueued: 0, klass: nil, of_class: nil)
      of_class ||= klass
      actual_completed = BawWorkers::ResqueApi.statuses(
        statuses: BawWorkers::ActiveJob::Status::STATUS_COMPLETED,
        of_class:
      )
      actual_failed = BawWorkers::ResqueApi.statuses(
        statuses: [
          BawWorkers::ActiveJob::Status::STATUS_FAILED,
          BawWorkers::ActiveJob::Status::STATUS_ERRORED
        ],
        of_class:
      )
      actual_enqueued = BawWorkers::ResqueApi.statuses(
        statuses: BawWorkers::ActiveJob::Status::STATUS_QUEUED,
        of_class:
      )
      aggregate_failures do
        # when the assertion fails due to count the error is unreadable
        # so we add a specific length assertion afterwards as well
        expect(actual_completed).to be_a(Array).and(have_attributes(count: completed))
        expect(actual_completed).to have(completed).items

        expect(actual_failed).to be_a(Array).and(have_attributes(count: failed))
        expect(actual_failed).to have(failed).items

        expect(actual_enqueued).to be_a(Array).and(have_attributes(count: enqueued))
        expect(actual_enqueued).to have(enqueued).items
      end
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
      audio_recording = Concurrent::Promises.future(connection_settings) { |cs|
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

      audio_recording.value!
    end

    # Pop a single job off of `queue_name` and run it locally.
    # Optionally yields the job before performing it (useful for setting up mocks).
    # @param [String] queue_name - the name of the queue to pop a job from
    # @param [ActiveJob::Base] block - yielded with the job just before it is performed
    # @return [Object] the result of `perform_now`
    def perform_job_locally(queue_name, &block)
      job = BawWorkers::ResqueApi.pop(queue_name)
      block.call(job) if block_given?
      job.perform_now
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

    # Run `count` jobs as soon as they're enqueued
    # Will NOT block for job completion!
    def perform_jobs_immediately(count:)
      total = BawWorkers::ResquePatch::PauseDequeueForTests.increment_perform_count(count)
      logger.info('Allowing for test jobs to be performed', { new: count, total: })
      expect(total).to be >= count
    end

    # wait for running jobs (either enqueued or running) to be completed for a short period.
    def wait_for_jobs(timeout: 5)
      started = Time.zone.now
      elapsed = 0
      count = 0
      while elapsed < timeout
        now = Time.zone.now
        elapsed = now - started

        statuses = BawWorkers::ResqueApi.statuses(
          statuses: [BawWorkers::ActiveJob::Status::STATUS_QUEUED, BawWorkers::ActiveJob::Status::STATUS_WORKING]
        )

        count = statuses.count - BawWorkers::ResqueApi.delayed_count

        logger.info('Waiting for test jobs to be performed', remaining: count)
        break if count <= 0

        sleep 0.5
      end

      logger.info('Finished waiting for test jobs to be performed', { remaining: count })
    end

    # Slow down a job by wrapping a target method in a remote job class with a proxy
    # that waits for a delay. If given a block the block will be run (on the client),
    # then the delay will occur (on the client), then finally
    # the target method is invoked (on the remote), and the job will resume normally.
    # YOU MUST invoke `.call` on return value of this function.
    # @param job [Class<::BawWorkers::Jobs::ApplicationJob>]
    # @param method [Symbol]
    # @param delay [Numeric] delay in seconds
    # @yield a callback executed just before the wait happens
    # @return [Proc] a waiter you must call to block with until the delay has occurred
    def introduce_delay(job_class:, method:, delay: 1, &block)
      raise ArgumentError, 'delay must be less than 30' if delay > 30

      BawWorkers::Jobs::IntroduceDelay.add_hook(job_class, method)

      # return a proc that will do the waiting
      lambda do
        started = Time.zone.now
        elapsed = 0
        loop do
          elapsed = Time.zone.now - started
          logger.info('IntroduceDelay: Waiting for job method to be invoked', elapsed:)
          sleep 0.1

          break if BawWorkers::Jobs::IntroduceDelay.waiting?
          raise 'IntroduceDelay: Timed out waiting for job hook' if elapsed > 30
        end

        logger.info('IntroduceDelay: Job hook hit, executing client hook')
        block&.call

        logger.info('IntroduceDelay: Sleep by', delay:)
        sleep delay

        logger.info('IntroduceDelay: Releasing job')

        BawWorkers::Jobs::IntroduceDelay.stop_waiting!
        BawWorkers::Jobs::IntroduceDelay.remove_hook
      end
    end

    # Perform a number of jobs and **BLOCK** execution until the jobs are completed.
    # Set a flag in redis that the Test worker listens for.
    # That worker will then complete the given number of jobs.
    # @param [Integer,nil] count the number of jobs to perform. Use `nil` to indicate that all enqueued jobs should be performed.
    # @param [Float] timeout the amount of time to wait for a job to finish
    # @return [Array<BawWorkers::ActiveJob::Status::StatusData>] an array of job statuses that were performed.
    def perform_jobs(count: nil, timeout: 30, wait_for_resque_failures: true)
      stats = job_stats
      existing = stats[:statuses].count
      count = stats[:total_pending] if count.nil?

      if stats[:total_pending] < count
        logger.warn("Can't perform #{count} jobs because there are only #{stats[:total_pending]} jobs in the queue")
      end

      logger.info "Performing #{count} jobs..."
      started = now

      expect(BawWorkers::ResquePatch::PauseDequeueForTests.set_perform_count(count)).to eq 'OK'

      statuses = []
      elapsed = 0
      error = loop {
        elapsed = now - started
        break 'Timed out waiting for jobs to finish' if elapsed > timeout

        job_stats => { statuses:, **stats }

        logger.info('Waiting for test jobs to be performed', { existing_statuses: existing, **stats })
        break if (stats[:status_execution_count] - existing) >= count

        sleep(0.5)
      }

      # from us reporting a failed status to this watcher receiving it, there is
      # not enough time for resque to report a failure (mainly due to email error templating time)
      error_statuses_count = statuses.select(&:errored?).count
      if wait_for_resque_failures && error_statuses_count.positive? && BawWorkers::ResqueApi.failed_count != error_statuses_count
        logger.info('Waiting for failures to be reported')
        sleep 0.5 until BawWorkers::ResqueApi.failed_count == error_statuses_count || (now - started) > (timeout + 10)
      end

      if error.present?
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
        enqueued:,
        delayed:,
        total_pending: enqueued + delayed,
        statuses:,
        statuses_count: statuses.count,
        status_execution_count: statuses.sum { |s| (s&.options&.fetch(:executions, nil) || 0) + 1 }
      }
    end

    def assert_mailer_job(message_type)
      jobs = expect_enqueued_jobs(1, of_class: ActionMailer::MailDeliveryJob)
      expect(jobs.first['args'].first['arguments'][1]).to eq(message_type)
    end

    def perform_mailer_job(message_type)
      assert_mailer_job(message_type)
      perform_jobs(count: 1)
    end

    def perform_purge_jobs
      while (purge_jobs = BawWorkers::ResqueApi.jobs_queued_of(ActiveStorage::PurgeJob)).any?
        # expect only jobs of this type
        expect_enqueued_jobs(purge_jobs.count, of_class: ActiveStorage::PurgeJob)

        perform_jobs(count: purge_jobs.count)
      end
    end

    private

    # like Time.now but ignores Timecop
    def now
      Time.now_without_mock_time
    end
  end
end

class FakeJob
  def self.perform(*job_args)
    {
      job_args:,
      result: Time.zone.now
    }
  end
end
