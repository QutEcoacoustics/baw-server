# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe 'HarvestJob can repair FL011', :clean_by_truncation do
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
      Fixtures.partial_file_FL011,
      harvest
    )
  end

  it 'sanity check: file needs repairs' do
    actual = Emu::Fix.check(@paths.absolute_path, Emu::Fix::FL_PARTIAL_FILE)
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
          'FL011' => {
            'status' => Emu::Fix::STATUS_FIXED,
            'check_result' => an_instance_of(Hash),
            'message' => 'Partial file repaired. New name is 20200426T020000Z_recovered.flac. Samples count was 317292544, new samples count is: 73035776. File truncated at 99824893.',
            'new_path' => a_string_matching(/20200426T020000Z_recovered.flac/)
          }
        )
      )
    ])

    # the latest audio recording is the one we just added
    actual = AudioRecording.last
    expect(actual).to have_attributes(
      status: 'ready',
      duration_seconds: a_value_within(0.001).of(3312.280090702948)
    )

    # and the file should be fixed on disk
    original_path = actual.original_file_paths.first
    expect(File).to exist(original_path)
    actual = Emu::Fix.check(Pathname(original_path), Emu::Fix::FL_PARTIAL_FILE)
    expect(actual.records.first[:problems].values.first[:status]).to eq Emu::Fix::CHECK_STATUS_REPAIRED
  end
end

describe 'HarvestJob ignores FL011 when empty', :clean_by_truncation do
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
      Fixtures.partial_file_FL011_empty,
      harvest
    )
  end

  it 'sanity check: file needs repairs' do
    actual = Emu::Fix.check(@paths.absolute_path, Emu::Fix::FL_PARTIAL_FILE)
    expect(actual.records.first[:problems].values.first[:status]).to eq Emu::Fix::CHECK_STATUS_AFFECTED
  end

  it 'rejects the file when harvesting' do
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
      harvest,
      @paths.harvester_relative_path,
      should_harvest: true
    )
    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    # even though emu supports partial empty files, we're quite happy for
    # our own validation to reject the file before it happens
    expect(HarvestItem.all.count).to eq 1
    item = HarvestItem.first
    expect(item).to be_failed
    expect(item.path).to eq @paths.harvester_relative_path.to_s
    expect(item.info[:fixes]).to match([])

    expect(item.info.to_h[:validations]).to match [
      {
        name: :file_empty,
        status: :not_fixable,
        message: 'File has no content (0 bytes)'
      }
    ]

    expect(item.absolute_path).to be_exist
    expect(AudioRecording.count).to eq 0
  end
end
