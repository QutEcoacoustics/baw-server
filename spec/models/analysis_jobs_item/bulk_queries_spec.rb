# frozen_string_literal: true

describe AnalysisJobsItem do
  describe 'bulk queries' do
    describe 'batch upsert' do
      # important to get a site with permissions for a user
      create_audio_recordings_hierarchy

      before do
        create_list(:audio_recording, 10, duration_seconds: 15, site:)
        create_list(:audio_recording, 2, duration_seconds: 10, site:)
      end

      let(:analysis_job) {
        # need to simulate the filter working
        create(
          :analysis_job,
          filter: {
            'duration_seconds' => {
              'eq' => 15
            }
          },
          creator: writer_user,
          project: site.region.project
        )
      }

      # 2 scripts
      # 13 recordings (on made by create_audio_recordings_hierarchy)
      # 2 recordings are too short, 1 too long (for the given filter)
      # 10 recordings are just right enough
      # 2 * 10 = 20 analysis jobs items
      it 'can create a batch of analysis jobs items' do
        expect(analysis_job.analysis_jobs_items.count).to be 0

        insert_count = AnalysisJobsItem.batch_insert_items_for_job(analysis_job)

        analysis_job.reload
        items = analysis_job.analysis_jobs_items
        expect(insert_count).to be 20
        expect(items.size).to be 20

        items.each do |item|
          expect(item.analysis_job).to eq(analysis_job)
          expect(item).to be_new
          expect(item.transition).to eq AnalysisJobsItem::TRANSITION_QUEUE
          expect(item.created_at).not_to be_blank
          expect(item.attempts).to be 0
          expect(item.script_id).to be_present
          expect(item).to be_valid
        end

        items.group_by(&:script_id).each do |_script_id, items_group|
          expect(items_group.size).to be 10
        end
      end

      it 'can be run again without creating duplicates' do
        # this models rerunning the job with new-recordings present

        # first pass
        insert_count = AnalysisJobsItem.batch_insert_items_for_job(analysis_job)
        expect(insert_count).to be 20

        # create some new recordings
        create_list(:audio_recording, 10, duration_seconds: 15, site:)

        # second pass
        insert_count = AnalysisJobsItem.batch_insert_items_for_job(analysis_job)
        expect(insert_count).to be 20

        analysis_job.reload
        items = analysis_job.analysis_jobs_items
        expect(items.size).to be 40
        expect(items).to all(be_new)
        expect(items).to all(be_valid)
      end

      it 'does not consume sequence IDs for existing records when run again' do
        # this tests that re-running on already-existing records (plus a batch of
        # new ones) only consumes sequence IDs for the newly inserted records.
        # Previously (with ON CONFLICT DO NOTHING without NOT EXISTS), the sequence
        # would advance by the total number of candidate rows (both old and new),
        # not just the new ones.

        # first pass - creates 20 records (10 recordings × 2 scripts)
        first_insert_count = AnalysisJobsItem.batch_insert_items_for_job(analysis_job)
        expect(first_insert_count).to be 20
        max_id_after_first = AnalysisJobsItem.maximum(:id)

        # simulate amending: add 5 new recordings that match the filter
        create_list(:audio_recording, 5, duration_seconds: 15, site:)

        # second pass - should only insert the 10 new records (5 new recordings × 2 scripts)
        second_insert_count = AnalysisJobsItem.batch_insert_items_for_job(analysis_job)
        expect(second_insert_count).to be 10

        max_id_after_second = AnalysisJobsItem.maximum(:id)

        # The sequence should only have advanced by the number of newly inserted records.
        # Without the NOT EXISTS filter, ON CONFLICT DO NOTHING would consume sequence IDs
        # for all 15 recordings × 2 scripts = 30 rows, not just the 10 new ones.
        expect(max_id_after_second - max_id_after_first).to eq second_insert_count
      end
    end

    describe 'batch updates' do
      let(:analysis_job) {
        create(:analysis_job)
      }

      describe 'batch cancel' do
        before do
          AnalysisJobsItem.aasm.state_machine.config.toggle(:no_direct_assignment) do
            AnalysisJobsItem::AVAILABLE_ITEM_STATUS_SYMBOLS.each do |status|
              item = build(:analysis_jobs_item, status:, analysis_job:)
              item.save(validate: false)
            end
          end
        end

        it 'can cancel all items for a job' do
          AnalysisJobsItem.batch_mark_items_to_cancel_for_job(analysis_job)
          analysis_job.reload

          # 3 items were respectively :new, :queued, and :working, so those should
          # be scheduled to be cancelled
          to_cancel = analysis_job.analysis_jobs_items.where(transition: AnalysisJobsItem::TRANSITION_CANCEL)
          expect(to_cancel.size).to be 3
          expect(to_cancel).to all(be_transition_cancel)
          # expect all items to have cancel_started_at set
          expect(to_cancel).to all(have_attributes(cancel_started_at: be_present))
        end
      end

      describe 'batch retry' do
        before do
          AnalysisJobsItem.aasm.state_machine.config.no_direct_assignment = false
          AnalysisJobsItem::ALLOWED_RESULTS.each do |result|
            item = build(
              :analysis_jobs_item,
              status: AnalysisJobsItem::STATUS_FINISHED,
              result:,
              analysis_job:
            )
            item.save(validate: false)
          end
          AnalysisJobsItem.aasm.state_machine.config.no_direct_assignment = true
        end

        it 'can retry all items for a job' do
          AnalysisJobsItem.batch_retry_items_for_job(analysis_job)

          analysis_job.reload

          # 3 items were respectively :failed, :cancelled, :killed, so those should
          # be scheduled to be retried
          to_retry = analysis_job.analysis_jobs_items.where(transition: AnalysisJobsItem::TRANSITION_RETRY)
          expect(to_retry.size).to be 3
          expect(to_retry).to all(be_transition_retry)
        end
      end
    end
  end
end
