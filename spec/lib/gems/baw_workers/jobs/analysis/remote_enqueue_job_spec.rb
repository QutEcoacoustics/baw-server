# frozen_string_literal: true

# limited tests here, most of the functionality is tested in the batch communicator specs
describe BawWorkers::Jobs::Analysis::RemoteEnqueueJob do
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
    expect_performed_jobs(expected_count, of_class: BawWorkers::Jobs::Analysis::RemoteEnqueueJob)
      .max_by(&:time)
  end

  stepwise 'the remote enqueue job' do
    step 'check initial state' do
      expect(AnalysisJobsItem.count).to eq(40)
      expect(AnalysisJobsItem.all.pluck(:status)).to all(eq('new'))
    end

    step 'works as expected' do
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
      status = get_last_status(1)

      expect(status).to be_completed
      expect(status.messages).to include 'Enqueued 10 of 10 jobs, sleeping now'

      # there are only 10 available slots, so only 10 jobs should be queued
      expect(AnalysisJobsItem.queued.count).to eq(10)
      expect(AnalysisJobsItem.status_new.count).to eq(30)

      # but because each of our jobs submits two scripts, we should have 10 jobs in the queue
      expect_enqueued_or_held_pbs_jobs(10)
    end

    step 'will not schedule more if there are no slots' do
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
      status = get_last_status(2)

      expect(status).to be_completed
      expect(status.messages).to include 'Remote queue cannot accept any further jobs'

      expect(AnalysisJobsItem.queued.count).to eq(10)
    end

    step 'simulate completion' do
      # simulate completion of a job
      AnalysisJobsItem.queued.each do |item|
        item.work
        item.finish!
      end
    end

    step 'will schedule more if there are slots' do
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
      status = get_last_status(3)

      expect(status).to be_completed
      expect(status.messages).to include 'Enqueued 10 of 10 jobs, sleeping now'

      expect(AnalysisJobsItem.queued.count).to eq(10)
      expect(AnalysisJobsItem.finished.count).to eq(10)
      expect_enqueued_or_held_pbs_jobs(10)
    end

    step 'simulate one task being cancelled' do
      item = AnalysisJobsItem.queued.first
      item.work
      item.cancel!
      expect(AnalysisJobsItem.queued.count).to eq(9)
    end

    step 'will schedule more if there are slots' do
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
      status = get_last_status(4)

      expect(status).to be_completed
      expect(status.messages).to include 'Enqueued 1 of 1 jobs, sleeping now'

      expect(AnalysisJobsItem.queued.count).to eq(10)
      expect(AnalysisJobsItem.finished.count).to eq(11)
      expect(AnalysisJobsItem.result_cancelled.count).to eq(1)
      expect_enqueued_or_held_pbs_jobs(10)
    end

    step 'simulate cancellation' do
      # simulate completion of a job
      AnalysisJobsItem.queued.each(&:cancel!)

      expect(AnalysisJobsItem.result_cancelled.count).to eq(11)
    end

    step 'retry items' do
      # 21 finished, 10 successful, 11 cancelled
      expect(AnalysisJobsItem.transition_queue.count).to eq(19)

      a1, a2 = AnalysisJob.all
      AnalysisJobsItem.batch_retry_items_for_job(a1)
      AnalysisJobsItem.batch_retry_items_for_job(a2)

      expect(
        AnalysisJobsItem.transition_queue.count +
        AnalysisJobsItem.transition_retry.count
      ).to eq(30)
    end

    step 'and everything will run until completion' do
      # result:nil are our completed items - no success state because we're not
      # actually running the remote jobs on this test so there's no result
      before_finished_count = AnalysisJobsItem.finished.merge(AnalysisJobsItem.result_nil).count
      3.times do |i|
        BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
        status = get_last_status(5 + i)

        expect(status).to be_completed
        expect(status.messages).to include 'Enqueued 10 of 10 jobs, sleeping now'

        # only 10 be queued in the remote queue at a time no matter how times
        # we try to enqueue more
        expect(AnalysisJobsItem.queued.count).to eq(10)
        expect_enqueued_or_held_pbs_jobs(10)

        # simulate completion of a job
        AnalysisJobsItem.queued.each(&:finish!)

        expect(AnalysisJobsItem.finished.merge(AnalysisJobsItem.result_nil).count).to eq(
          before_finished_count + ((i + 1) * 10)
        )
      end
    end

    step 'and everything should have been run' do
      expect(AnalysisJobsItem.finished.count).to eq(40)
      expect(AnalysisJobsItem.transition_nil.count).to eq(40)
      # result:nil are our completed items - no success state because we're not
      # actually running the remote jobs on this test so there's no result
      expect(AnalysisJobsItem.result_nil.count).to eq(40)
    end

    step 'and there is nothing else to do' do
      BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_now
      status = get_last_status(8)

      expect(status).to be_completed
      expect(status.messages).to include 'Nothing left to enqueue'
    end
  end
end
