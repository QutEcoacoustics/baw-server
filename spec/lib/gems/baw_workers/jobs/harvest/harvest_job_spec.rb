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
            'problems' => a_hash_including({
              'FL010' => a_hash_including({
                'status' => ::Emu::Fix::STATUS_NOOP
              })
            })
          })
        ],
        file_info: {
          path: '',
          notes: {
            relative_path: "harvest_#{harvest.id}/20211012T132457_label.ogg"
          },
          prefix: '',
          suffix: '_label',
          site_id: site.id,
          channels: 1,
          extension: 'ogg',
          file_hash: 'SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891',
          file_name: '20211012T132457_label.ogg',
          recursive: false,
          media_type: 'audio/ogg',
          utc_offset: '+10:00',
          access_time: be_an_instance_of(String),
          change_time: be_an_instance_of(String),
          uploader_id: harvest.creator_id,
          bit_rate_bps: 239_920,
          modified_time: be_an_instance_of(String),
          recorded_date: '2021-10-12T13:24:57.000+10:00',
          duration_seconds: 70.0,
          data_length_bytes: 822_281,
          sample_rate_hertz: 44_100.0,
          recorded_date_local: '2021-10-12T13:24:57.000+00:00'
        },
        validations: []
      }
    }

    # while our harvest model is very strict about what states it can be in
    # it should not actually care or reject successful harvest jobs
    # this lets us avoid all those tricky distributed systems things that can be a pain
    prepare_harvest_with_mappings do
      [
        ::BawWorkers::Jobs::Harvest::Mapping.new(
          path: '',
          site_id: site.id,
          utc_offset: '+10:00',
          recursive: false
        )
      ]
    end

    before do
      # copy in a file fixture to harvest
      name = generate_recording_name(
        Time.new(2021, 10, 12, 13, 24, 57, 'Z'),
        suffix: 'label',
        ambiguous: true,
        extension: '.ogg'
      )
      @paths = copy_fixture_to_harvest_directory(
        Fixtures.audio_file_mono,
        harvest,
        target_name: name
      )
    end

    def enqueue_and_perform(should_harvest:, completed: 1)
      enqueued = BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
        harvest,
        @paths.harvester_relative_path,
        should_harvest:
      )

      expect(enqueued).to be true
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

      perform_jobs(count: 1)
      expect_jobs_to_be completed:, of_class: BawWorkers::Jobs::Harvest::HarvestJob
    end

    context 'when getting metadata from a file' do
      it 'works' do
        enqueue_and_perform(should_harvest: false)

        # should not have harvested
        expect(AudioRecording.count).to be_zero

        # @type [HarvestItem]
        item = HarvestItem.first
        aggregate_failures do
          expect(item.audio_recording_id).to be_nil
          expect(item).to be_metadata_gathered
          expect(item.info.to_h).to match(a_hash_including(info))
          expect(item.file_deleted?).to be false
          expect(item.absolute_path.exist?).to be true
        end
      end
    end

    context 'when doing a full harvest' do
      it 'works' do
        enqueue_and_perform(should_harvest: true)

        # @type [HarvestItem]
        item = HarvestItem.first
        aggregate_failures do
          expect(item).to be_completed
          expect(item.info.to_h).to match(a_hash_including(info))
          expect(item.file_deleted?).to be false
          expect(item.absolute_path.exist?).to be true
        end

        # should have harvested
        expect(AudioRecording.count).to eq 1
        audio_recording = AudioRecording.first
        expect(item.audio_recording_id).to eq audio_recording.id

        # check the audio recording
        attributes = {
          id: be_an_instance_of(Integer),
          uuid: be_an_instance_of(String),
          uploader_id: harvest.creator_id,
          recorded_date: Time.parse('2021-10-12T13:24:57.000+10:00'),
          site_id: site.id,
          duration_seconds: 70.0,
          sample_rate_hertz: 44_100,
          channels: 1,
          bit_rate_bps: 239_920,
          media_type: 'audio/ogg',
          data_length_bytes: 822_281,
          file_hash: 'SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891',
          status: 'ready',
          notes: {
            relative_path: "harvest_#{harvest.id}/20211012T132457_label.ogg"
          },
          creator_id: harvest.creator_id,
          updater_id: nil,
          deleter_id: nil,
          original_file_name: '20211012T132457_label.ogg',
          recorded_utc_offset: '+10:00'
        }
        aggregate_failures do
          attributes.each do |key, value|
            expect(audio_recording.send(key)).to match value
          end
        end

        expect(audio_recording).to be_original_file_exists

        dir = audio_original.possible_paths_dir({ uuid: audio_recording.uuid }).first
        filename = audio_original.file_name_uuid({ uuid: audio_recording.uuid, original_format: 'ogg' })
        v3_name_path = "#{dir}/#{filename}"
        expect(audio_recording.original_file_paths).to eq [v3_name_path]

        # this is the job that deletes the file from harvester_to_do
        expect_delayed_jobs(1)
      end

      it 'will delete the harvest file after a period of time' do
        enqueue_and_perform(should_harvest: true)

        # @type [HarvestItem]
        item = HarvestItem.first
        aggregate_failures do
          expect(item).to be_completed
          expect(item.info.to_h).to match(a_hash_including(info))
          expect(item.file_deleted?).to be false
          expect(item.absolute_path.exist?).to be true
        end

        # should have harvested
        expect(AudioRecording.count).to eq 1

        # this is the job that deletes the file from harvester_to_do
        expect_delayed_jobs(1)
        BawWorkers::ResqueApi.enqueue_delayed_jobs
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob)
        perform_jobs(count: 1)
        expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::DeleteHarvestItemFileJob

        item.reload
        expect(item.file_deleted?).to be true
        expect(item.absolute_path.exist?).to be false
      end

      it 'can be attempted again if a validation fails' do
        # make it invalid
        harvest.mappings = nil
        harvest.save!

        enqueue_and_perform(should_harvest: false)

        # @type [HarvestItem]
        item = HarvestItem.first
        aggregate_failures do
          expect(item).to be_metadata_gathered
          expect(item.info.to_h[:validations]).to eq [
            {
              name: :ambiguous_date_time,
              status: :fixable,
              message: 'Only a local date/time was found, supply a UTC offset'
            },
            {
              name: :no_site_id,
              status: :fixable,
              message: 'No site id found. Add a mapping.'
            }
          ]
        end

        # now provide a mapping and attempt again
        harvest.mappings << ::BawWorkers::Jobs::Harvest::Mapping.new(
          path: '',
          site_id: site.id,
          utc_offset: '+10:00',
          recursive: false
        )
        harvest.save!

        # this is the second job we've completed this test
        enqueue_and_perform(should_harvest: true, completed: 2)

        # should have been enqueued again,
        # and a duplicate extra harvest item should not have been made
        expect(HarvestItem.count).to eq 1

        # should have harvested
        item.reload
        aggregate_failures do
          expect(item).to be_completed
          expect(item.info.to_h[:validations]).to eq []
          expect(AudioRecording.count).to eq 1
        end
      end
    end
  end
end
