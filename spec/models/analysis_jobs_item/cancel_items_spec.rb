# frozen_string_literal: true

describe AnalysisJobsItem do
  describe 'batch cancellation optimization' do
    include PBSHelpers

    # the methods cancel! and cancel_items! should behave identically
    # but operate in different ways: state machine vs. batch operation.
    # This is a bit of maintenance pit, so we're going to test heavily.

    let(:analysis_job) { create(:analysis_job) }

    submit_pbs_jobs_as_held

    def common_assertions(time_taken:)
      items = create_list(:analysis_jobs_item, 10, analysis_job: analysis_job)

      queue_ids = items.map(&:queue_id)

      items.each(&:queue!)

      expect(queue_ids).to all(be_present)
      expect(items).to all(be_queued)
      items.sample(3).each do |item|
        expect(BawWorkers::Config.batch_analysis.job_exists?(item).value!).to be true
      end

      assert_analysis_statistics

      AnalysisJobsItem.batch_mark_items_to_cancel_for_job(analysis_job)

      items = items.map(&:reload)

      expect {
        yield items
      }.to perform_under(time_taken).sec.warmup(0)

      expect(items.map(&:reload)).to all(
        be_finished
        .and(be_result_cancelled)
        .and(be_transition_empty)
        .and(have_attributes(
          cancel_started_at: be_present,
          finished_at: be_present,
          queue_id: be_nil
        ))
      )

      # and in either case

      expect(BawWorkers::Config.batch_analysis.count_enqueued_jobs.value!).to eq(0)
      assert_analysis_statistics
    end

    # stats are only incremented on successful completion
    def assert_analysis_statistics
      expect(Statistics::UserStatistics.totals).to match(a_hash_including(
        analyzed_audio_duration: nil,
        analyses_completed_count: nil
      ))
      expect(Statistics::AudioRecordingStatistics.totals).to match(a_hash_including(
        analyses_completed_count: nil
      ))
    end

    it 'works for cancel!' do
      common_assertions(time_taken: 5) do |items|
        items.each(&:cancel!)
      end
    end

    it 'works for cancel_items!' do |_items|
      common_assertions(time_taken: 0.5) do
        AnalysisJobsItem.cancel_items!(analysis_job).value!
      end
    end
  end
end
