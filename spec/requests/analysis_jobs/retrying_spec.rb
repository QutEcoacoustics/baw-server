# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs', :clean_by_truncation do
  include_context 'with analysis jobs context'

  stepwise 'retrying' do
    step 'alter one of the scripts so that it fails' do
      script_one.update!(executable_command: 'echo "{source} {output_dir}" && exit 1')
    end

    step 'we can create a job' do
      create_job
    end

    step '(1st attempt) and then run the job to completion' do
      process_jobs(count: 20)
    end

    step '(1st attempt) the job should be completed' do
      job = current_job
      expect(job).to be_completed
    end

    step '(1st attempt) we should see a completed email job' do
      perform_mailer_job('completed_job_message')
    end

    step '(1st attempt) and our stats should be as expected' do
      assert_job_progress(
        status_finished_count: 20,
        transition_empty_count: 20,
        result_failed_count: 10,
        result_success_count: 10
      )
    end

    step '(2nd attempt) but we can retry the job' do
      transition_job(transition: :retry, token: admin_token)
    end

    step '(2nd attempt) the job should be updated' do
      job = current_job
      expect(job).to be_processing
      expect(job.retry_count).to eq(1)
    end

    step '(2nd attempt) and just the failures should be marked as transition retry' do
      assert_job_progress(
        status_finished_count: 20,
        transition_empty_count: 10,
        transition_retry_count: 10,
        result_failed_count: 10,
        result_success_count: 10
      )
    end

    step '(2nd attempt) and a retry email should be in the queue to be sent' do
      perform_mailer_job('retry_job_message')
    end

    step '(2nd attempt) and then run the job to completion' do
      # only 10 need to be retried
      process_jobs(count: 10, assert_progress: false)
    end

    step '(2nd attempt) the job should be completed' do
      job = current_job
      expect(job).to be_completed
    end

    step '(2nd attempt) we should have a completed email in the queue' do
      perform_mailer_job('completed_job_message')
    end

    step '(2nd attempt) and our stats should be as expected' do
      assert_job_progress(
        status_finished_count: 20,
        transition_empty_count: 20,
        result_failed_count: 10,
        result_success_count: 10
      )
    end

    step 'now make it so the jobs do not fail' do
      script_one.update!(executable_command: 'echo "{source} {output_dir}"')
    end

    step '(3rd attempt) we can retry the job' do
      transition_job(transition: :retry, token: admin_token)
    end

    step '(3rd attempt) the job should be updated' do
      job = current_job
      expect(job).to be_processing
      expect(job.retry_count).to eq(2)
    end

    step '(3rd attempt) and just the failures should be marked as transition retry' do
      assert_job_progress(
        status_finished_count: 20,
        transition_empty_count: 10,
        transition_retry_count: 10,
        result_failed_count: 10,
        result_success_count: 10
      )
    end

    step '(3rd attempt) and a retry email should be in the queue to be sent' do
      perform_mailer_job('retry_job_message')
    end

    step '(3rd attempt) and then run the job to completion' do
      process_jobs(count: 10, assert_progress: false)
    end

    step '(3rd attempt) the job should be completed' do
      job = current_job
      expect(job).to be_completed
    end

    step '(3rd attempt) and our stats should be as expected' do
      assert_job_progress(
        status_finished_count: 20,
        transition_empty_count: 20,
        result_success_count: 20
      )
    end
  end
end
