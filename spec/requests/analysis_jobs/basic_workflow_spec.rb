# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs', :clean_by_truncation do
  include_context 'with analysis jobs context'

  stepwise 'basic workflow' do
    step 'create a job' do
      create_job
    end

    step 'we should see updated stats' do
      # 10 recordings, 2 scripts, 20 job items
      assert_job_totals(overall_count: 20)
      assert_job_progress(status_new_count: 20, transition_queue_count: 20, result_empty_count: 20)

      # nothing in redis - scheduled job takes care on enqueueing
      expect_enqueued_jobs(0)
      # nothing on remote queue - scheduled job has not run yet
      expect_pbs_jobs(0)
    end

    step 'we can fetch the job from the api' do
      hash = fetch_job
      assert_job_progress(**hash[:overall_progress])
      expect(hash).to match(a_hash_including(
        script_ids: contain_exactly(script_one.id, script_two.id),
        audio_event_import_ids: []
      ))
    end

    step 'then the enqueue job runs' do
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_later
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::RemoteEnqueueJob)
      perform_jobs(count: 1)
    end

    step 'we should see updated stats' do
      assert_job_progress(
        status_new_count: 10,
        status_queued_count: 10,
        transition_queue_count: 10,
        transition_empty_count: 10,
        result_empty_count: 20
      )

      # 20 on remote queue
      expect_pbs_jobs(10)
    end

    step 'release the jobs and let them run' do
      release_all_held_pbs_jobs
    end

    step 'wait for the jobs to finish' do
      wait_for_pbs_jobs_to_finish(count: 10)
    end

    step '10 items should be wanting to finish' do
      assert_job_progress(
        status_new_count: 10,
        status_working_count: 10,
        transition_queue_count: 10,
        transition_finish_count: 10,
        result_empty_count: 20
      )
    end

    step 'then the status check job runs' do
      BawWorkers::Jobs::Analysis::RemoteStatusCheckJob.perform_later
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::RemoteStatusCheckJob)
      perform_jobs(count: 1)
    end

    step 'now half the items are finished!' do
      assert_job_progress(
        status_new_count: 10,
        status_queued_count: 0,
        status_finished_count: 10,
        transition_queue_count: 10,
        transition_empty_count: 10,
        result_empty_count: 10,
        result_success_count: 10
      )
    end

    step 'there should be 10 result import jobs' do
      expect_enqueued_jobs(10, of_class: BawWorkers::Jobs::Analysis::ImportResultsJob)
      perform_jobs(count: 10)
    end

    step 'repeat the cycle' do
      process_jobs(count: 10)
    end

    step 'now all the items are finished!' do
      assert_job_progress(
        status_new_count: 0,
        status_finished_count: 20,
        transition_empty_count: 20,
        result_success_count: 20
      )
    end

    step 'and the job should have finished too' do
      # the last job item to finish will trigger the job to complete
      expect(current_job).to be_completed
    end
  end
end
