# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe BawWorkers::Jobs::Harvest::HarvestJob, :clean_by_truncation do
  include_context 'shared_test_helpers'

  prepare_users
  prepare_project
  prepare_region
  prepare_site

  before do
    clear_original_audio
    clear_harvester_to_do
  end

  context 'when harvesting' do
    # while our harvest model is very strict about what states it can be in
    # it should not actually care or reject successful harvest jobs
    # this lets us avoid all those tricky distributed systems things that can be a pain
    prepare_harvest_with_mappings do
      [
        BawWorkers::Jobs::Harvest::Mapping.new(
          path: '',
          site_id: site.id,
          utc_offset: '+10:00',
          recursive: false
        )
      ]
    end

    before do
      # copy in a file fixture to harvest
      @paths = copy_fixture_to_harvest_directory(
        Fixtures.bar_lt_file,
        harvest
      )
    end

    def enqueue_and_perform
      enqueued = BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
        harvest,
        @paths.harvester_relative_path,
        should_harvest: true
      )

      expect(enqueued).to be true
      wait_for_jobs(timeout: 10)
    end

    it 'works' do
      expect {
        enqueue_and_perform
      }.to perform_under(5.6).sec.warmup(0)

      expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob
      # @type [HarvestItem]
      item = HarvestItem.first
      aggregate_failures do
        expect(item).to be_completed
        expect(item.file_deleted?).to be false
        expect(item.absolute_path.exist?).to be true
      end

      # should have harvested
      expect(AudioRecording.count).to eq 1
      audio_recording = AudioRecording.first
      expect(item.audio_recording_id).to eq audio_recording.id
      expect(audio_recording.duration_seconds).to be_within(0.1).of(audio_file_bar_lt_metadata[:duration_seconds])

      expect(audio_recording).to be_original_file_exists
    end
  end
end
