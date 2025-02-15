# frozen_string_literal: true

describe BawWorkers::Jobs::Analysis::RemoteCancelJob do
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
      of_class: BawWorkers::Jobs::Analysis::RemoteCancelJob
    ).max_by(&:time)
  end

  # this is arguably overkill, but unless we test both fast and slow
  # then we have poor coverage and no guarantee that the more complex slow branch
  # ever works
  [true, false].each do |use_batch|
    stepwise "can cancel items in a job (#{use_batch ? 'batch/fast' : 'slow/one-by-one'})" do
      if use_batch
        define_method(:assert_message) do |status, count|
          expect(status.messages).to include "Batch cancelled #{count} items"
        end
      else
        define_method(:assert_message) do |status, count|
          if count.zero?
            expect(status.messages).to include 'Nothing found to cancel'
          else
            expect(status.messages).to include "Found batch of items to cancel, count: #{count}"
          end
        end
      end

      unless use_batch
        step 'disable batch cancelling' do
          allow(BawWorkers::Config.batch_analysis).to(
            receive(:cancel_all_jobs!).and_return(Dry::Monads::Result::Failure.new('failed by mock'))
          )
        end
      end

      step 'add some items to the remote queue' do
        # add some to the remote queue - the query that runs will sample
        # evenly across jobs, so 5 queued items per job
        BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
        expect(AnalysisJobsItem.queued.count).to eq(10)
        expect(AnalysisJobsItem.status_new.count).to eq(30)
      end

      step 'attempt to cancel some items' do
        analysis_job = analysis_jobs_matrix[:analysis_jobs].first
        # run the cancel job - at this stage we expect nothing to change because
        # there a no jobs scheduled to be cancelled
        BawWorkers::Jobs::Analysis::RemoteCancelJob.perform_now(analysis_job.id)
      end

      step 'the job should do nothing' do
        status = get_last_status(1)
        assert_message(status, 0)
      end

      step 'and we expect nothing to change' do
        expect(AnalysisJobsItem.queued.count).to eq(10)
        expect(AnalysisJobsItem.status_new.count).to eq(30)
      end

      step 'now cancel everything from the first job' do
        analysis_job = analysis_jobs_matrix[:analysis_jobs].first
        AnalysisJobsItem.batch_mark_items_to_cancel_for_job(analysis_job)

        expect(AnalysisJobsItem.transition_cancel.count).to eq(20)
      end

      step 'and run the cancel job again' do
        analysis_job = analysis_jobs_matrix[:analysis_jobs].first
        BawWorkers::Jobs::Analysis::RemoteCancelJob.perform_now(analysis_job.id)
      end

      step 'the job should have cancelled all items' do
        status = get_last_status(2)

        # 10 :new, 10 :cancelled
        assert_message(status, 20)
      end

      step 'and we expect the items to be cancelled' do
        # the second job should be untouched
        # the seconds job still has 5 items queued
        expect(AnalysisJobsItem.queued.count).to eq(5)
        expect(AnalysisJobsItem.status_new.count).to eq(15)
        expect(AnalysisJobsItem.result_cancelled.count).to eq(20)
      end

      step 'half of the queued items remain on the remote queue' do
        expect_enqueued_or_held_pbs_jobs(5)
      end

      step 'when second job is cancelled' do
        analysis_job = analysis_jobs_matrix[:analysis_jobs].second
        AnalysisJobsItem.batch_mark_items_to_cancel_for_job(analysis_job)
      end

      step 'and run the cancel job again' do
        analysis_job = analysis_jobs_matrix[:analysis_jobs].second
        BawWorkers::Jobs::Analysis::RemoteCancelJob.perform_now(analysis_job.id)
      end

      step 'the job should have cancelled all items' do
        status = get_last_status(3)
        # 10 :new, 10 :cancelled
        assert_message(status, 20)
      end

      step 'and we expect the items to be cancelled' do
        expect(AnalysisJobsItem.queued.count).to eq(0)
        expect(AnalysisJobsItem.status_new.count).to eq(0)
        expect(AnalysisJobsItem.result_cancelled.count).to eq(40)
      end

      step 'no items remain on the remote queue' do
        expect_enqueued_or_held_pbs_jobs(0)
      end
    end
  end
end
