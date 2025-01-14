# frozen_string_literal: true

describe BawWorkers::Jobs::Analysis::RemoteStaleCheckJob do
  include PBSHelpers

  create_audio_recordings_hierarchy

  # prepare a matrix of analysis jobs, scripts, and audio recordings
  create_analysis_jobs_matrix(
    analysis_jobs_count: 2,
    scripts_count: 2,
    audio_recordings_count: 10
  )

  pause_all_jobs
  submit_pbs_jobs_as_held

  def get_last_status(expected_count)
    expect_performed_jobs(
      expected_count,
      of_class: BawWorkers::Jobs::Analysis::RemoteStaleCheckJob
    ).max_by(&:time)
  end

  it 'can be performed later' do
    BawWorkers::Jobs::Analysis::RemoteStaleCheckJob.perform_later!(nil)

    expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::RemoteStaleCheckJob)

    perform_jobs(count: 1)

    expect_performed_jobs(1, of_class: BawWorkers::Jobs::Analysis::RemoteStaleCheckJob)
  end

  stepwise 'can resolve stale jobs' do
    after do
      Timecop.return
    end

    step 'add some items to the remote queue' do
      # add some to the remote queue - the query that runs will sample
      # evenly across jobs, so 5 queued items per job
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
      expect(AnalysisJobsItem.queued.count).to eq(10)
      expect(AnalysisJobsItem.status_new.count).to eq(30)
    end

    step 'attempt to resolve some stale items' do
      BawWorkers::Jobs::Analysis::RemoteStaleCheckJob.perform_now(nil)
    end

    step 'the job should do nothing' do
      status = get_last_status(1)
      expect(status.messages).to include 'Nothing left to check'
    end

    step 'and we expect nothing to change' do
      expect(AnalysisJobsItem.queued.count).to eq(10)
      expect(AnalysisJobsItem.status_new.count).to eq(30)
    end

    step 'now run all the jobs' do
      release_all_held_pbs_jobs

      AnalysisJobsItem.queued.each do |item|
        wait_for_pbs_job item.queue_id
      end
    end

    # now we're not running the web server so all webhooks will fail to run

    step 'all the jobs are finished on the remote queue' do
      expect_enqueued_or_held_pbs_jobs(0)
    end

    step 'but we see no transition finished because the webhooks failed' do
      expect(AnalysisJobsItem.finished.count).to eq(0)
      expect(AnalysisJobsItem.transition_finish.count).to eq(0)
    end

    step 'attempt again to resolve some stale items' do
      BawWorkers::Jobs::Analysis::RemoteStaleCheckJob.perform_now(nil)
    end

    step 'the job should do nothing because the items are not old enough' do
      status = get_last_status(2)
      expect(status.messages).to include 'Nothing left to check'
    end

    step 'and we expect nothing to change' do
      expect(AnalysisJobsItem.queued.count).to eq(10)
      expect(AnalysisJobsItem.status_new.count).to eq(30)
    end

    step 'travel to the future' do
      Timecop.travel(36.hours.from_now)
    end

    step 'attempt for the third time to resolve some stale items' do
      BawWorkers::Jobs::Analysis::RemoteStaleCheckJob.perform_now(nil)
    end

    step 'the job should do nothing because the items are not old enough' do
      status = get_last_status(1)
      expect(status.messages).to include 'Checked 10 jobs, 10 were marked as finished, sleeping now'
    end

    step 'and we expect ten items to finish and be marked as failed' do
      expect(AnalysisJobsItem.queued.count).to eq(0)
      expect(AnalysisJobsItem.finished.count).to eq(10)
      expect(AnalysisJobsItem.result_failed.count).to eq(10)
      expect(AnalysisJobsItem.status_new.count).to eq(30)
    end

    step 'no items remain on the remote queue' do
      expect_enqueued_or_held_pbs_jobs(0)
    end
  end
end
