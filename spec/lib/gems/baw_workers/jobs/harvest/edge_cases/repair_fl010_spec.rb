# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe 'HarvestJob can repair FL010', :clean_by_truncation do
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

    # copy in a file fixture to harvest
    @paths = copy_fixture_to_harvest_directory(
      Fixtures.bar_lt_faulty_duration,
      harvest
    )
  end

  it 'sanity check: file needs repairs' do
    actual = Emu::Fix.check(@paths.absolute_path, Emu::Fix::FL_DURATION_BUG)
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
          'FL010' => {
            'status' => 'Fixed',
            'check_result' => an_instance_of(Hash),
            'message' => 'Old total samples was 317292544, new total samples is: 158646272',
            'new_path' => nil
          }
        )
      )
    ])

    # the latest audio recording is the one we just added
    actual = AudioRecording.last
    expect(actual).to have_attributes(
      status: 'ready',
      # the original file has a duration that is twice as long as it actually is
      # 158,646,272 / 22,050 = 7,194.842267573696145124716553288
      duration_seconds: a_value_within(0.001).of(7_194.842)
    )

    # and the file should be fixed on disk
    original_path = actual.original_file_paths.first
    expect(File).to exist(original_path)
    actual = Emu::Fix.check(Pathname(original_path), Emu::Fix::FL_DURATION_BUG)
    expect(actual.records.first[:problems].values.first[:status]).to eq Emu::Fix::CHECK_STATUS_REPAIRED
  end
end
