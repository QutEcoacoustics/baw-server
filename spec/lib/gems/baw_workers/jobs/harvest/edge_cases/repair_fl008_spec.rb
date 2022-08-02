# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe 'HarvestJob can repair FL008', :clean_by_truncation do
  require 'support/shared_test_helpers'

  include_context 'shared_test_helpers'

  prepare_users
  prepare_project
  prepare_region
  prepare_site

  prepare_harvest_with_mappings do
    [
      ::BawWorkers::Jobs::Harvest::Mapping.new(
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

    # copy in a file fixture to harvest
    @paths = copy_fixture_to_harvest_directory(
      Fixtures.bar_lt_file,
      harvest,
      # space is intentional! that's the bug!
      target_name: '201909 3T000000+1000_REC.flac'
    )
  end

  it 'sanity check: file needs repairs' do
    actual = Emu::Fix.check(@paths.absolute_path, Emu::Fix::FL_SPACE_IN_DATESTAMP)
    expect(actual.records.first[:problems].values.first[:status]).to eq Emu::Fix::CHECK_STATUS_AFFECTED
  end

  it 'repairs the file when harvesting' do
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
      harvest,
      @paths.harvester_relative_path,
      should_harvest: true
    )
    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    expect(HarvestItem.all.count).to eq 1
    item = HarvestItem.first
    expect(item).to be_completed
    expect(item.info[:fixes]).to match([
      a_hash_including(
        'problems' => a_hash_including(
          'FL008' => a_hash_including(
            'status' => 'Fixed',
            'check_result' => an_instance_of(Hash),
            'message' => 'Inserted `0` into datestamp',
            'new_path' => item.absolute_path.to_s
          )
        )
      )
    ])

    # the latest audio recording is the one we just added
    actual = AudioRecording.last
    expect(actual).to have_attributes(
      status: 'ready',
      original_file_name: '20190903T000000+1000_REC.flac'
    )
  end
end
