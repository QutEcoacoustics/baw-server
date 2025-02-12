# frozen_string_literal: true

require 'aasm/rspec'

describe AnalysisJobsItem do
  describe 'state machine' do
    pause_all_jobs
    ignore_pending_jobs
    include Dry::Monads[:result]

    let(:analysis_jobs_item) {
      create(:analysis_jobs_item)
    }

    def set_job_status_mock(result)
      case result
      when AnalysisJobsItem::RESULT_SUCCESS then 'success'
      when AnalysisJobsItem::RESULT_FAILED then 'failed'
      when AnalysisJobsItem::RESULT_KILLED then 'killed'
      when AnalysisJobsItem::RESULT_CANCELLED then 'cancelled'
      end => result

      allow(BawWorkers::Config.batch_analysis).to receive(:job_status).and_return(
        BawWorkers::BatchAnalysis::Models::JobStatus.new(
          result:,
          status: BawWorkers::BatchAnalysis::Models::JobStatus::STATUS_FINISHED,
          raw: {},
          job_id: 'iamanqueueid',
          error: result == AnalysisJobsItem::RESULT_SUCCESS ? nil : 'error message',
          used_walltime_seconds: 123,
          used_memory_bytes: 456
        )
      )
    end

    before do
      allow(BawWorkers::Config.batch_analysis).to receive_messages(submit_job: Success('iamanqueueid'),
        cancel_job: Success(''), clear_job: Success(''))
    end

    def assert_stats(analysis_jobs_item, user_count = nil, user_duration = nil, recording_count = nil)
      expect(Statistics::UserStatistics.totals).to match(a_hash_including(
        analyses_completed_count: user_count,
        analyzed_audio_duration: user_duration
      ))

      expect(
        Statistics::AudioRecordingStatistics.totals_for(analysis_jobs_item.audio_recording)
      ).to match(a_hash_including(analyses_completed_count: recording_count))
    end

    it 'defines the queue event' do
      expect(analysis_jobs_item).to transition_from(:new).to(:queued).on_event(:queue)
    end

    it 'defines the work event' do
      expect(analysis_jobs_item).to transition_from(:queued).to(:working).on_event(:work)
    end

    it 'defines the finish event' do
      set_job_status_mock(AnalysisJobsItem::RESULT_SUCCESS)
      expect(analysis_jobs_item).to transition_from(:working).to(:finished).on_event(:finish)
      expect(analysis_jobs_item).to transition_from(:queued).to(:finished).on_event(:finish)
      expect(analysis_jobs_item).to transition_from(:finished).to(:finished).on_event(:finish)

      assert_stats(analysis_jobs_item, 3, analysis_jobs_item.audio_recording.duration_seconds * 3, 3)
    end

    it 'defines the cancel event' do
      set_job_status_mock(AnalysisJobsItem::RESULT_CANCELLED)
      expect(analysis_jobs_item).to transition_from(:new).to(:finished).on_event(:cancel)
      expect(analysis_jobs_item).to transition_from(:working).to(:finished).on_event(:cancel)
      expect(analysis_jobs_item).to transition_from(:queued).to(:finished).on_event(:cancel)

      assert_stats(analysis_jobs_item)
    end

    it 'defines the retry event' do
      expect(analysis_jobs_item).to transition_from(:finished).to(:queued).on_event(:retry)
    end

    describe 'callbacks for states' do
      let(:item) { create(:analysis_jobs_item, queue_id: nil) }

      example 'initial state' do
        expect(item).to be_new
        expect(item).to be_transition_queue
        expect(item.created_at).to be_within(1.second).of Time.zone.now
        expect(item.queue_id).to be_nil
        expect(item.attempts).to be 0

        assert_stats(analysis_jobs_item)
      end

      example 'new -> queued' do
        item.transition_queue!
        expect(item.queue!).to be true

        expect(item).to be_queued
        expect(item).to be_transition_empty
        expect(item.queue_id).to eq 'iamanqueueid'
        expect(item.queued_at).to be_within(1.second).of Time.zone.now
        expect(item.attempts).to be 1

        assert_stats(analysis_jobs_item)
      end

      example 'new -> queued (when cancelling)' do
        item.transition_cancel!
        expect(item).to be_transition_cancel

        expect {
          item.queue!
        }.to raise_error(
          AASM::InvalidTransition,
          "Event 'queue' cannot transition from 'new'. Failed callback(s): [:not_cancelled?]."
        )

        expect(item).to be_new
        expect(item).to be_transition_cancel
      end

      example 'queued -> working' do
        item.queue!
        expect(item.work!).to be true

        expect(item).to be_working
        expect(item).to be_transition_empty
        expect(item.work_started_at).to be_within(1.second).of Time.zone.now
        expect(item.queue_id).to eq 'iamanqueueid'
        expect(item.attempts).to be 1

        assert_stats(analysis_jobs_item)
      end

      AnalysisJobsItem::ALLOWED_RESULTS.each do |result|
        example "working -> finished (#{result})" do
          item.queue!
          item.work!

          item.transition_finish!

          set_job_status_mock(result)

          expect(item.finish!).to be true

          expect(item.result).to eq result

          expect(item).to be_transition_empty
          expect(item.finished_at).to be_within(1.second).of Time.zone.now
          expect(item.queue_id).to be_blank
          expect(item.attempts).to be 1
          expect(item.error).to eq(result == AnalysisJobsItem::RESULT_SUCCESS ? nil : 'error message')
          expect(item.used_walltime_seconds).to eq 123
          expect(item.used_memory_bytes).to eq 456

          if result == AnalysisJobsItem::RESULT_SUCCESS
            expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::ImportResultsJob)
            assert_stats(item, 1, item.audio_recording.duration_seconds, 1)
          else
            assert_stats(item)
          end
        end
      end

      example 'new -> finished (cancelled)' do
        item.transition = AnalysisJobsItem::TRANSITION_CANCEL
        expect(item.cancel!).to be true

        expect(item).to be_result_cancelled
        # cancel started at is not modified by the state machine but rather it's
        # set by the batch_mark_items_to_cancel_for_job method.
        expect(item.cancel_started_at).to be_nil
        expect(item.finished_at).to be_within(1.second).of Time.zone.now

        expect(item.queue_id).to be_nil
        expect(item).to be_transition_empty
        expect(item.attempts).to be 0
        assert_stats(analysis_jobs_item)
      end

      example 'queued -> finished (cancelled)' do
        item.queue!

        set_job_status_mock(AnalysisJobsItem::RESULT_CANCELLED)

        item.transition = AnalysisJobsItem::TRANSITION_CANCEL
        expect(item.cancel!).to be true

        expect(item).to be_result_cancelled
        expect(item.cancel_started_at).to be_nil
        expect(item.finished_at).to be_within(1.second).of Time.zone.now
        expect(item.queue_id).to be_nil
        expect(item).to be_transition_empty
        expect(item.attempts).to be 1
        assert_stats(analysis_jobs_item)
      end

      example 'working -> finished (cancelled)' do
        item.queue!
        item.work!

        set_job_status_mock(AnalysisJobsItem::RESULT_CANCELLED)

        item.transition = AnalysisJobsItem::TRANSITION_CANCEL
        expect(item.cancel!).to be true

        expect(item).to be_result_cancelled
        expect(item.cancel_started_at).to be_nil
        expect(item.finished_at).to be_within(1.second).of Time.zone.now
        expect(item.queue_id).to be_nil
        expect(item).to be_transition_empty
        expect(item.attempts).to be 1
        assert_stats(analysis_jobs_item)
      end

      example 'retrying: finished -> queued' do
        item.queue!
        item.work!

        set_job_status_mock(AnalysisJobsItem::RESULT_CANCELLED)
        item.cancel!

        item.transition = AnalysisJobsItem::TRANSITION_RETRY
        expect(item.retry!).to be true

        expect(item).to be_queued
        expect(item).to be_transition_empty
        expect(item.queue_id).to eq 'iamanqueueid'
        expect(item.attempts).to be 2

        expect(item.work!).to be true
        expect(item).to be_working
        expect(item.work_started_at).to be_within(1.second).of Time.zone.now
        expect(item.queue_id).to eq 'iamanqueueid'
        expect(item.attempts).to be 2
        assert_stats(analysis_jobs_item)
      end
    end
  end
end
