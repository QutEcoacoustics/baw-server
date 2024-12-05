# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe 'HarvestJob will reject files with an ambiguous date', :clean_by_truncation do
  include_context 'shared_test_helpers'

  prepare_users
  prepare_project
  prepare_region
  prepare_site

  prepare_harvest_with_mappings do
    [
      BawWorkers::Jobs::Harvest::Mapping.new(
        path: '',
        site_id: site.id,
        utc_offset: nil,
        recursive: false
      )
    ]
  end

  pause_all_jobs

  before do
    clear_original_audio
    clear_harvester_to_do
  end

  it 'will reject missing dates' do
    paths = copy_fixture_to_harvest_directory(
      Fixtures.audio_file_mono,
      harvest
    )

    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths.harvester_relative_path, should_harvest: true)

    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    item = HarvestItem.first
    aggregate_failures do
      expect(item).to be_failed
      expect(item.info.to_h[:validations]).to eq [
        {
          name: :missing_date,
          status: :fixable,
          message: 'We could not find a recorded date for this file'
        }
      ]
    end
  end

  it 'will reject ambiguous dates' do
    date = Time.new(2022, 1, 1, 0, 0, 0, '+00:00')
    name = generate_recording_name(date, ambiguous: true)

    paths = copy_fixture_to_harvest_directory(
      Fixtures.audio_file_mono,
      harvest,
      target_name: name
    )

    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths.harvester_relative_path, should_harvest: true)

    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    item = HarvestItem.first
    aggregate_failures do
      expect(item).to be_failed
      expect(item.info.to_h[:validations]).to eq [
        {
          name: :ambiguous_date_time,
          status: :fixable,
          message: 'Only a local date/time was found, supply a UTC offset'
        }
      ]
    end
  end

  it 'can use recursive mappings to resolve reject ambiguous dates' do
    harvest.mappings = [
      BawWorkers::Jobs::Harvest::Mapping.new(
        path: '',
        site_id: site.id,
        utc_offset: '-11:00',
        recursive: true
      )
    ]
    harvest.save!

    date = Time.new(2022, 1, 1, 0, 0, 0, '+00:00')
    name = generate_recording_name(date, ambiguous: true)

    paths = copy_fixture_to_harvest_directory(
      Fixtures.audio_file_mono,
      harvest,
      target_name: name,
      sub_directories: ['a', 'b']
    )

    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths.harvester_relative_path, should_harvest: true)

    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    item = HarvestItem.first
    aggregate_failures do
      expect(item).to be_completed
      expect(item.info.to_h[:validations]).to eq []
      expect(AudioRecording.first.as_json).to match(a_hash_including(
        'original_file_name' => '20220101T000000.wav',
        'recorded_utc_offset' => '-11:00'
      ))
    end
  end
end
