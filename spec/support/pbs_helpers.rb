# frozen_string_literal: true

module PBSHelpers
  def self.included(base)
    base.extend(ExampleGroup)
    base.include(Example)
  end

  module ExampleGroup
    # Causes any new PBS jobs to be submitted as held.
    # Useful for testing system state while things are "paused".
    def submit_pbs_jobs_as_held
      before do
        # no need for cleanup: state is stored in redis which is wiped
        # after each test
        BawWorkers::PBS::Connection::SubmitHeldJobsForTests.modify_should_hold(true)
      end
    end
  end

  module Example
    # @!attribute [r] connection
    #   @return [PBS::Connection]

    def self.included(base)
      base.let(:connection) {
        PBS::Connection.new(Settings.batch_analysis, Settings.organisation_names.site_short_name)
      }

      base.before do
        connection.clean_all_jobs
      end

      base.after do
        connection.clean_all_jobs

        BawWorkers::PBS::Connection::SubmitHeldJobsForTests.modify_should_hold(false)
      end
    end

    def release_all_held_pbs_jobs
      connection.fetch_all_statuses.value!.jobs.each do |id, job|
        next unless job.held?

        connection.release_job(id)
      end
    end

    # wait for the to be at least `count` jobs marked as finished
    # @return [Array<::PBS::Models::Job>]
    def wait_for_pbs_jobs_to_finish(count:, timeout: 30)
      logger.info('Waiting for all PBS jobs to finish')

      started = now
      elapsed = 0
      finished = {}
      error = loop {
        elapsed = now - started
        break 'Timed out waiting for jobs to finish' if elapsed > timeout

        jobs = connection.fetch_all_statuses.value!.jobs

        finished.merge!(jobs.filter { |_key, value| value.finished? })

        logger.debug(
          'Job statuses',
          finished_count: finished.count,
          jobs: jobs.transform_values(&:job_state)
        )

        break if finished.count >= count

        logger.info(
          'Waiting for PBS jobs to be performed',
          elapsed:,
          finished_count: finished.count
        )

        sleep 0.5
      }

      raise error.to_s if error.present?

      logger.info(
        'Finished waiting for PBS jobs',
        elapsed:,
        finished_count: finished.count
      )

      finished.values
    end

    # @return [::PBS::Models::Job,nil]
    def wait_for_pbs_job(job_id, timeout: 30)
      logger.info('Waiting for PBS job', job_id:)
      started = now
      elapsed = 0
      job = nil
      error = loop {
        elapsed = now - started
        break 'Timed out waiting for job to finish' if elapsed > timeout

        result = connection.fetch_status(job_id)
        if result.failure?
          if result.failure =~ /Unknown Job Id/
            logger.error('Job not found', job_id:, error: result.failure)
            break
          else
            # will raise
            result.value!
          end
        end

        job = result.value!

        break if job.finished?

        logger.info('Waiting for PBS job to be performed', job_id:, job_state: job.job_state, elapsed:)

        sleep 0.5
      }

      if error.present?
        logger.error('Error waiting for PBS job', job_id:, error: error, elapsed:)
        raise error.to_s
      end

      logger.info('Finished waiting for PBS job', job_id:, job_state: job&.job_state, elapsed:)

      job
    end

    def wait_for_pbs_job_and_dependents(job_id, timeout: 30)
      todo = [job_id]
      jobs = []

      loop do
        current = todo.shift
        job = wait_for_pbs_job(current, timeout:)
        jobs << job

        break if job.depend.blank?

        logger.info('Waiting for PBS job dependents', job_id:, depend: job.depend)

        todo += job.depend.values.flatten
      end

      logger.info('Finished waiting', job_id:, total_jobs: jobs.size)

      jobs
    end

    def expect_pbs_jobs(count)
      jobs = connection.fetch_all_statuses.value!.jobs
      expect(jobs.size).to eq(count)

      jobs
    end

    # @return [Integer] the number of enqueued or held jobs
    def expect_enqueued_or_held_pbs_jobs(count)
      connection
        .fetch_all_statuses
        .value!
        .jobs
        .filter { |_key, value| value.queued? || value.held? }
        .size => enqueued

      expect(enqueued).to eq(count)

      enqueued
    end
  end
end
