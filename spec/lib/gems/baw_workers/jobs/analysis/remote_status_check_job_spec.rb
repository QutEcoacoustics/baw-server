# frozen_string_literal: true

describe BawWorkers::Jobs::Analysis::RemoteStatusCheckJob do
  include PBSHelpers

  create_audio_recordings_hierarchy

  # prepare a matrix of analysis jobs, scripts, and audio recordings
  create_analysis_jobs_matrix(
    analysis_jobs_count: 2,
    scripts_count: 2,
    audio_recordings_count: 10
  )

  pause_all_jobs

  # we don't actually want any of these jobs to run
  submit_pbs_jobs_as_held

  def get_last_status(expected_count)
    expect_performed_jobs(
      expected_count,
      of_class: BawWorkers::Jobs::Analysis::RemoteStatusCheckJob
    ).max_by(&:time)
  end

  stepwise 'finish items in a job' do
    4.times do |index|
      step 'add some items to the remote queue' do
        # add some to the remote queue - the query that runs will sample
        # evenly across jobs, so 5 queued items per job
        BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
        expect(AnalysisJobsItem.queued.count).to eq(10)
        expect(AnalysisJobsItem.status_new.count).to eq(40 - ((index + 1) * 10))
      end

      step 'schdule items to finish' do
        AnalysisJobsItem.queued.each(&:transition_finish!)
      end

      step 'sanity check: some items from each job should be queued' do
        first, second = analysis_jobs_matrix[:analysis_jobs]
        expect(first.analysis_jobs_items.queued.count).to eq(5)
        expect(second.analysis_jobs_items.queued.count).to eq(5)
      end

      step 'attempt to finish those items' do
        # run the finish job
        BawWorkers::Jobs::Analysis::RemoteStatusCheckJob.perform_now
      end

      step 'the job should have finished the items' do
        status = get_last_status(index + 1)
        expect(status.messages).to include 'Finished 10 jobs, sleeping now'
      end

      step 'and we expect updates to the models' do
        expect(AnalysisJobsItem.finished.count).to eq((index + 1) * 10)
        expect(AnalysisJobsItem.status_new.count).to eq(40 - ((index + 1) * 10))
      end
    end

    step 'running the finish job with no items left does nothing' do
      BawWorkers::Jobs::Analysis::RemoteStatusCheckJob.perform_now
    end

    step 'check status' do
      status = get_last_status(5)
      expect(status.messages).to include 'Nothing left to finish'
    end

    step 'and we expect no updates to the models' do
      expect(AnalysisJobsItem.finished.count).to eq(40)
    end

    step 'no items remain on the remote queue' do
      expect_enqueued_or_held_pbs_jobs(0)
    end
  end
end
