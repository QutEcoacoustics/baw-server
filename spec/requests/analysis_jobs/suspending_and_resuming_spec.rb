# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs', :clean_by_truncation do
  include_context 'with analysis jobs context'

  stepwise 'suspending and resuming' do
    step 'create a job' do
      create_job
    end

    step 'we should see updated stats' do
      assert_job_progress(
        status_new_count: 20,
        transition_queue_count: 20,
        result_empty_count: 20
      )
    end

    step 'add some jobs to the remote queue' do
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_later
      perform_jobs(count: 1)
      expect_pbs_jobs(10)
    end

    step 'we should see updated stats' do
      assert_job_progress(
        status_new_count: 10,
        status_queued_count: 10,
        transition_queue_count: 10,
        transition_empty_count: 10,
        result_empty_count: 20
      )
    end

    step 'now we suspend the job' do
      transition_job(transition: :suspend, token: admin_token)
    end

    step 'the job should be suspended' do
      expect(current_job).to be_suspended
    end

    step 'we should see everything is set to be transition cancel' do
      assert_job_progress(
        status_new_count: 10,
        status_queued_count: 10,
        transition_cancel_count: 20,
        result_empty_count: 20
      )
    end

    step 'and we should see the cancel job is enqueued' do
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::RemoteCancelJob)
    end

    step 'when cancel job is run' do
      perform_jobs(count: 1)
    end

    step 'then we see the remote queue is cleared' do
      expect_pbs_jobs(0)
    end

    step 'and we see the batch cancel was in effect' do
      status = expect_performed_jobs(1, of_class: BawWorkers::Jobs::Analysis::RemoteCancelJob).first
      expect(status).to be_completed
      expect(status.messages).to include('Batch cancelled 20 items')
    end

    step 'and we see all items are cancelled' do
      assert_job_progress(
        status_finished_count: 20,
        transition_cancel_count: 0,
        transition_empty_count: 20,
        result_cancelled_count: 20
      )
    end

    step 'if we attempt to process some jobs' do
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_later
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::RemoteEnqueueJob)
      perform_jobs(count: 1)
    end

    step 'we see that none will enqueue because they are not set to transition queue' do
      assert_job_progress(
        status_finished_count: 20,
        transition_cancel_count: 0,
        transition_empty_count: 20,
        result_cancelled_count: 20
      )

      expect_pbs_jobs(0)
    end

    step 'we resume the job' do
      transition_job(transition: :resume, token: admin_token)
    end

    step 'the job should be resumed' do
      expect(current_job).to be_processing
    end

    step 'we see updated stats' do
      assert_job_progress(
        status_finished_count: 20,
        transition_retry_count: 20,
        result_cancelled_count: 20
      )
    end

    step 'then we process the jobs' do
      process_jobs(count: 20, assert_progress: false)
    end

    step 'then the job should be completed' do
      expect(current_job).to be_completed
    end

    step 'and the updated stats should read successful' do
      assert_job_progress(
        status_new_count: 0,
        status_finished_count: 20,
        transition_empty_count: 20,
        result_success_count: 20
      )
    end

    # step 'and a job completion email job should be waiting' do
    #   perform_mailer_job('completed_job_message')
    # end
  end
end
