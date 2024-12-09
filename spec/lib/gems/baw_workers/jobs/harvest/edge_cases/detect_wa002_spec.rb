# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe 'HarvestJob can detect WA002', :clean_by_truncation do
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
      Fixtures.problem_WA002,
      harvest
    )
  end

  it 'sanity check: file needs repairs' do
    actual = Emu::Fix.check(@paths.absolute_path, Emu::Fix::WA_NO_DATA)
    expect(actual.records.first[:problems].values.first[:status]).to eq Emu::Fix::CHECK_STATUS_AFFECTED
  end

  it 'rejects the file when harvesting (should_harvest: false)' do
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
      harvest,
      @paths.harvester_relative_path,
      should_harvest: false
    )
    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    expect(HarvestItem.all.count).to eq 1
    item = HarvestItem.first
    expect(item).to be_failed
    expect(item.path).to eq @paths.harvester_relative_path.to_s
    expect(item.info[:fixes]).to match([
      a_hash_including(
        'problems' => a_hash_including(
          'WA002' => a_hash_including(
            'status' => Emu::Fix::STATUS_NOT_FIXED,
            'check_result' => a_hash_including(
              'status' => Emu::Fix::CHECK_STATUS_AFFECTED,
              'message' => 'The file has only null bytes and has no usable data.'
            ),
            'message' => nil,
            'new_path' => nil
          )
        )
      )
    ])

    expect(item.info.to_h[:validations]).to match [
      {
        name: :wa002,
        status: :not_fixable,
        message: a_string_matching(/The file has only null bytes and has no usable data./)
      }
    ]

    expect(item.absolute_path).to be_exist
    expect(AudioRecording.count).to eq 0
  end

  it 'rejects the file when harvesting (should_harvest: true)' do
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
      harvest,
      @paths.harvester_relative_path,
      should_harvest: true
    )
    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    expect(HarvestItem.all.count).to eq 1
    item = HarvestItem.first
    expect(item).to be_failed
    expect(item.path).to eq @paths.harvester_relative_path.to_s
    expect(item.info[:fixes]).to match([
      a_hash_including(
        'problems' => a_hash_including(
          'WA002' => a_hash_including(
            'status' => Emu::Fix::STATUS_NOT_FIXED,
            'check_result' => a_hash_including(
              'status' => Emu::Fix::CHECK_STATUS_AFFECTED,
              'message' => 'The file has only null bytes and has no usable data.'
            ),
            'message' => nil,
            'new_path' => nil
          )
        )
      )
    ])

    expect(item.info.to_h[:validations]).to match [
      {
        name: :wa002,
        status: :not_fixable,
        message: a_string_matching(/The file has only null bytes and has no usable data/)
      }
    ]

    expect(item.absolute_path).to be_exist
    expect(AudioRecording.count).to eq 0
  end

  it 'rejects the file when harvesting (even after metadata extraction)' do
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
      harvest,
      @paths.harvester_relative_path,
      should_harvest: false
    )
    perform_jobs(count: 1)
    expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
      harvest,
      @paths.harvester_relative_path,
      should_harvest: true
    )
    perform_jobs(count: 1)
    expect_jobs_to_be completed: 2, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    expect(HarvestItem.all.count).to eq 1
    item = HarvestItem.first
    expect(item).to be_failed
    expect(item.path).to eq @paths.harvester_relative_path.to_s
    expect(item.info[:fixes]).to match([
      a_hash_including(
        'version' => 1,
        'problems' => a_hash_including(
          'WA002' => a_hash_including(
            'status' => Emu::Fix::STATUS_NOT_FIXED,
            'check_result' => a_hash_including(
              'status' => Emu::Fix::CHECK_STATUS_AFFECTED,
              'message' => 'The file has only null bytes and has no usable data.'
            ),
            'message' => nil,
            'new_path' => nil
          )
        )
      ),
      a_hash_including(
        'version' => 2,
        'problems' => a_hash_including(
          'WA002' => a_hash_including(
            'status' => Emu::Fix::STATUS_NOT_FIXED,
            'check_result' => a_hash_including(
              'status' => Emu::Fix::CHECK_STATUS_AFFECTED,
              'message' => 'The file has only null bytes and has no usable data.'
            ),
            'message' => nil,
            'new_path' => nil
          )
        )
      )
    ])

    expect(item.info.to_h[:validations]).to match [
      {
        name: :wa002,
        status: :not_fixable,
        message: a_string_matching(/The file has only null bytes and has no usable data./)
      }
    ]

    expect(item.absolute_path).to be_exist
    expect(AudioRecording.count).to eq 0
  end
end
