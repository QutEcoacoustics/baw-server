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

  it 'correctly parses an end date out of a file name' do
    paths = copy_fixture_to_harvest_directory(
      Fixtures.bar_lt_file,
      harvest,
      target_name: 'S20240815T091156.982648+1000_E20240815T091251.967555+1000_-12.34567+78.98102.wav'
    )

    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths.harvester_relative_path, should_harvest: true)

    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    item = HarvestItem.first
    aggregate_failures do
      expect(item).to be_completed
      expect(item.info.to_h[:file_info]).to match(a_hash_including(
        recorded_date: '2024-08-15T09:11:56.982648+10:00',
        recorded_date_local: '2024-08-15T09:11:56.982648'
      ))
    end
  end
end
