# frozen_string_literal: true

module PBSHelpers
  module Example
    # @!attribute [r] connection
    #   @return [PBS::Connection]

    def self.included(base)
      base.let(:connection) {
        PBS::Connection.new(Settings.batch_analysis)
      }

      base.before do
        connection.clean_all_jobs
      end

      base.after do
        connection.clean_all_jobs
      end
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

        _, job = connection.fetch_status(job_id).value!

        break if job.finished?

        logger.info('Waiting for PBS job to be performed', job_id:, job_state: job.job_state)

        sleep 0.5
      }

      raise error.to_s unless error.blank?

      logger.info('Finished waiting for PBS job', job_id:, job_state: job.job_state, elapsed:)

      job
    end

    def expect_pbs_jobs(count)
      jobs = connection.fetch_all_jobs.value!.jobs
      expect(jobs.size).to eq(count)

      jobs
    end

    def expect_enqueued_pbs_jobs(count)
      enqueued = connection.fetch_all_jobs.value!.jobs.where(&:queued?).size
      expect(enqueued).to eq(count)

      enqueued
    end
  end
end
