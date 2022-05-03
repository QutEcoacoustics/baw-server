# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe BawWorkers::Jobs::Harvest::HarvestJob, :clean_by_truncation do
  require 'support/shared_test_helpers'

  include_context 'shared_test_helpers'

  prepare_users
  prepare_project
  prepare_region
  prepare_site

  pause_all_jobs

  before do
    clear_original_audio
    clear_harvester_to_do
  end

  let(:queue_name) { Settings.actions.harvest.queue }

  context 'when checking basic job behaviour' do
    it 'works on the harvest queue' do
      expect((BawWorkers::Jobs::Harvest::HarvestJob.queue_name)).to eq(queue_name)
    end

    it 'can enqueue' do
      item = create(:harvest_item)
      BawWorkers::Jobs::Harvest::HarvestJob.perform_later!(item.id, false)
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

      clear_pending_jobs
    end

    it 'has a sensible name' do
      item = create(:harvest_item)

      job = BawWorkers::Jobs::Harvest::HarvestJob.new(item.id, true)

      expected = "HarvestItem(#{item.id}), should_harvest: true"
      expect(job.name).to eq(expected)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      expect_enqueued_jobs(0)

      job = BawWorkers::Jobs::Harvest::HarvestJob.perform_later!(1, true)
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      expect(job.job_id).not_to be_nil

      job2 = BawWorkers::Jobs::Harvest::HarvestJob.new(1, true)
      expect(job2.enqueue).to be false

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      expect(job2.job_id).to eq job.job_id
      expect(job2.unique?).to be false

      clear_pending_jobs
    end
  end

  context 'when harvesting' do
    let(:info) {
      {
        error: nil,
        fixes: [

          a_hash_including({
            problems: a_hash_including({
              FL010: a_hash_including({
                status: ::Emu::Fix::CHECK_STATUS_UNAFFECTED
              })
            })
          })
        ],
        file_info: {
          path: '',
          notes: {},
          prefix: '',
          suffix: '_label',
          site_id: site.id,
          channels: 1,
          extension: 'ogg',
          file_hash: 'SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891',
          file_name: '20221012T132457_label.ogg',
          recursive: false,
          media_type: 'audio/ogg',
          utc_offset: '+10:00',
          access_time: be_an_instance_of(String),
          change_time: be_an_instance_of(String),
          uploader_id: harvest.creator_id,
          bit_rate_bps: 239_920,
          modified_time: be_an_instance_of(String),
          recorded_date: '2022-10-12T13:24:57.000+10:00',
          duration_seconds: 70.0,
          data_length_bytes: 822_281,
          sample_rate_hertz: 44_100.0,
          recorded_date_local: '2022-10-12T13:24:57.000+00:00'
        },
        validations: []
      }
    }
    # while our harvest model is very strict about what states it can be in
    # it should not actually care or reject successful harvest jobs
    # this lets us avoid all those tricky distributed systems things that can be a pain
    let(:harvest) {
      h = build(:harvest)
      h.mappings << ::BawWorkers::Jobs::Harvest::Mapping.new(
        path: '',
        site_id: site.id,
        utc_offset: '+10:00',
        recursive: false
      )
      h.save!
      h
    }

    let!(:rel_path) { "#{harvest.upload_directory_name}/20221012T132457_label.ogg" }
    let!(:target) { harvester_to_do_path / rel_path }

    before do
      # copy in a file fixture to harvest
      target.dirname.mkpath
      FileUtils.copy(Fixtures.audio_file_mono, target)
    end

    context 'when getting metadata from a file' do
      it 'works' do
        enqueued = BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
          harvest,
          rel_path,
          should_harvest: false
        )

        expect(enqueued).to be true
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

        perform_jobs(count: 1)
        expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

        # should not have harvested
        expect(AudioRecording.count).to be_zero

        # @type [HarvestItem]
        item = HarvestItem.first
        aggregate_failures do
          expect(item.audio_recording_id).to be_nil
          expect(item).to be_metadata_gathered
          expect(item.info.to_h).to match(a_hash_including(info))
        end
      end
    end
  end
end
