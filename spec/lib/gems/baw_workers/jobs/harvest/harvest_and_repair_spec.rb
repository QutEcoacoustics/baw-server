# frozen_string_literal: true

describe 'harvesting a file that needs repairs' do
  require 'support/shared_test_helpers'
  extend WebServerHelper::ExampleGroup

  include_context 'shared_test_helpers'

  expose_app_as_web_server
  create_audio_recordings_hierarchy
  pause_all_jobs

  let!(:target) { harvester_to_do_path / Fixtures.bar_lt_faulty_duration.basename }

  before do
    clear_original_audio
    clear_harvester_to_do

    # generate a harvest.yml file
    harvest_yml_path = harvester_to_do_path / BawWorkers::Jobs::Harvest::Metadata.filename
    template = BawWorkers::Jobs::Harvest::Metadata.generate_yaml(project.id, site.id, owner_user, recursive: false,
      utc_offset: '+10')
    harvest_yml_path.write(template)

    # copy in a file fixture to harvest
    FileUtils.copy(Fixtures.bar_lt_faulty_duration, target)
  end

  it 'sanity check: file needs repairs' do
    actual = Emu::Fix.check(target, Emu::Fix::FL_DURATION_BUG)
    expect(actual.records.first[:problems].values.first[:status]).to eq Emu::Fix::CHECK_STATUS_AFFECTED
  end

  it 'harvests and repairs the file', :clean_by_truncation, :slow do
    # enqueue the file in the harvest folder
    BawWorkers::Jobs::Harvest::Enqueue.scan(harvester_to_do_path, true)

    expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::Action)
    expect(HarvestItem.all.count).to eq 1
    expect(HarvestItem.first.status).to eq HarvestItem::STATUS_NEW

    perform_jobs(count: 1)

    expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::Action)
    expect(HarvestItem.all.count).to eq 1
    expect(HarvestItem.first.status).to eq HarvestItem::STATUS_COMPLETED
    expect(HarvestItem.first.info[:fixes]).to match([
      a_hash_including(
        'file' => target.to_s,
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
