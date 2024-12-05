# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob, :clean_by_truncation do
  include_context 'shared_test_helpers'

  prepare_users
  prepare_project
  prepare_region
  prepare_site
  prepare_audio_recording

  pause_all_jobs

  let(:queue_name) { Settings.actions.harvest_delete.queue }

  context 'when checking basic job behaviour' do
    prepare_harvest
    prepare_harvest_item

    it 'has a delete_after class method' do
      expect(BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.delete_after).to eq Settings.actions.harvest_delete.delete_after
    end

    it 'works on the harvest queue' do
      expect(BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.queue_name).to eq(queue_name)
    end

    it 'can enqueue' do
      BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.delete_later(harvest_item)
      expect_enqueued_jobs(0)
      expect_delayed_jobs(1)
    end

    it 'has a sensible name' do
      job = BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.new(harvest_item.id)

      expected = "DeleteHarvestItemFile:#{harvest_item.id}"
      expect(job.name).to eq(expected)
    end

    it 'does enqueue the same payload into the same queue (queuing as if idempotent)' do
      expect_enqueued_jobs(0)

      job = BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.perform_later!(1)
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob)
      expect(job.job_id).not_to be_nil

      job2 = BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.perform_later!(1)
      expect_enqueued_jobs(2, of_class: BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob)
      expect(job2.job_id).not_to be_nil

      clear_pending_jobs
    end
  end

  context 'when deleting' do
    prepare_harvest
    prepare_harvest_item

    # we'll have left over harvest jobs at the end of the test which we do not want to process
    # (they are tested elsewhere)
    ignore_pending_jobs

    # create a file to delete
    let(:target) {
      name = generate_recording_name(Time.zone.now)
      path = harvest.upload_directory / name

      path.touch

      path
    }

    before do
      clear_original_audio
      clear_harvester_to_do

      harvest.upload_directory.mkdir

      harvest_item.path = "#{harvest.upload_directory_name}/#{target.basename}"
      harvest_item.save
    end

    stepwise 'deleting job workflow' do
      step 'check our file exists' do
        expect(harvest_item.absolute_path).to be_exist
      end

      [
        [HarvestItem::STATUS_NEW, 1, 1],
        [HarvestItem::STATUS_METADATA_GATHERED, 2, 2],
        [HarvestItem::STATUS_FAILED, 3, 2],
        [HarvestItem::STATUS_ERRORED, 4, 2]
      ].each do |spec|
        state, completed, enqueued = spec

        step "set our status to #{state}" do
          harvest_item.status = state
          harvest_item.save!
          expect(harvest_item.status).to eq state
        end

        step "performing the delete jobs should not fail for #{state}" do
          BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.perform_later!(harvest_item.id)
          perform_jobs(count: 1)
          expect_jobs_to_be completed:, enqueued:, of_class: BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob
        end

        step 'but our file still exists' do
          expect(harvest_item.absolute_path).to be_exist
        end

        step 'and the harvest item does not record the file as deleted' do
          harvest_item.reload
          expect(harvest_item.deleted).to be false
        end
      end

      step 'set our status to completed' do
        harvest_item.status = HarvestItem::STATUS_COMPLETED
        harvest_item.save!
        expect(harvest_item).to be_completed
      end

      step 'performing the delete jobs should not fail for completed' do
        BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.perform_later!(harvest_item.id)
        perform_jobs(count: 1)
        expect_jobs_to_be completed: 5, enqueued: 2, of_class: BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob
      end

      step 'our file should be deleted' do
        expect(harvest_item.absolute_path).not_to be_exist
      end

      step 'and the harvest item records the file as deleted' do
        harvest_item.reload
        expect(harvest_item.deleted).to be true
      end

      step 'performing the delete job again should not fail (it is idempotent)' do
        BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob.perform_later!(harvest_item.id)
        perform_jobs(count: 1)
        expect_jobs_to_be completed: 6, enqueued: 2, of_class: BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob
      end

      step 'our file should be deleted' do
        expect(harvest_item.absolute_path).not_to be_exist
      end

      step 'and the harvest item records the file as deleted' do
        harvest_item.reload
        expect(harvest_item.deleted).to be true
      end
    end
  end
end
