# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe 'HarvestJob can process files with dollar signs in their names', :clean_by_truncation do
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
        utc_offset: '+10:00',
        recursive: false
      )
    ]
  end

  pause_all_jobs

  before do
    clear_original_audio
    clear_harvester_to_do
  end

  it 'works' do
    paths = copy_fixture_to_harvest_directory(
      Fixtures.audio_file_mono,
      harvest,
      target_name: '20160506$175304.wav'
    )

    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths.harvester_relative_path, should_harvest: true)

    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    item = HarvestItem.first

    expect(item).to be_completed
  end
end
