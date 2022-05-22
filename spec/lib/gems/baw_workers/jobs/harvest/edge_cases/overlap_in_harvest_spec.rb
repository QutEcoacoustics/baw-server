# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe 'HarvestJob can deal with overlaps in harvest', :clean_by_truncation do
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
  end

  let(:duration) { 30 }

  def prepare_file(date, frequency)
    name = generate_recording_name(date)
    temp = generate_audio(name, sine_frequency: frequency, duration:)

    copy_fixture_to_harvest_directory(temp, harvest)
  end

  it 'can repair minor overlaps' do
    # create three recordings that overlap with the target file in a minor way
    overlap = 4.0

    start1 = Time.new(2022, 1, 1, 0, 0, 0, '+00:00')
    start2 = start1 + (duration - overlap)
    start3 = start2 + (duration - overlap)

    # generate three files adn copy in a file fixture to harvest
    # generating is required here so we don't fail validation on duplicate hash check

    paths1 = prepare_file(start1, 6000)
    paths2 = prepare_file(start2, 8000)
    paths3 = prepare_file(start3, 10_000)

    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths1.harvester_relative_path, should_harvest: true)
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths2.harvester_relative_path, should_harvest: true)
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths3.harvester_relative_path, should_harvest: true)

    perform_jobs(count: 3)
    expect_jobs_to_be completed: 3, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    expect(HarvestItem.all.count).to eq 3
    items = HarvestItem.all
    expect(items).to all(be_completed)

    # the latest audio recording is the one we just added
    recordings = AudioRecording.all
    expect(recordings).to all(have_attributes(status: AudioRecording::STATUS_READY.to_s))
    a1, a2, a3 = recordings

    trimmed_duration = (duration - overlap)
    aggregate_failures do
      # we always trim off the end of the recordings
      # a1 should have had its duration trimmed when we inserted a2
      expect(a1.duration_seconds.to_f).to be_within(0.01).of(trimmed_duration)
      # a2 needed to be trimmed to fit before a2
      expect(a2.duration_seconds.to_f).to be_within(0.01).of(trimmed_duration)
      # a3 should be unaffected
      expect(a3.duration_seconds.to_f).to be_within(0.01).of(duration)

      expect(a1.notes[:duration_adjustment_for_overlap]).to match(
        [
          {
            changed_at: an_instance_of(String),
            overlap_amount: be_within(0.01).of(overlap),
            old_duration: be_within(0.01).of(duration),
            new_duration: be_within(0.01).of(trimmed_duration),
            other_uuid: a2.uuid
          }
        ]
      )
      expect(a2.notes[:duration_adjustment_for_overlap]).to match(
        [
          {
            changed_at: an_instance_of(String),
            overlap_amount: be_within(0.01).of(overlap),
            old_duration: be_within(0.01).of(duration),
            new_duration: be_within(0.01).of(trimmed_duration),
            other_uuid: a3.uuid
          }
        ]
      )
      expect(a3.notes[:duration_adjustment_for_overlap]).to be_nil
    end
  end

  it 'will reject large overlaps' do
    # create recordings that overlap with the target file in a minor way
    overlap = 20.0

    start1 = Time.new(2022, 1, 1, 0, 0, 0, '+00:00')
    start2 = start1 + (duration - overlap)
    start3 = start2 + (duration - overlap)

    # generate three files adn copy in a file fixture to harvest
    # generating is required here so we don't fail validation on duplicate hash check
    paths1 = prepare_file(start1, 6000)
    paths2 = prepare_file(start2, 8000)
    paths3 = prepare_file(start3, 10_000)

    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths1.harvester_relative_path, should_harvest: true)
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths2.harvester_relative_path, should_harvest: true)
    BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths3.harvester_relative_path, should_harvest: true)

    perform_jobs(count: 3)
    expect_jobs_to_be completed: 3, of_class: BawWorkers::Jobs::Harvest::HarvestJob

    aggregate_failures do
      expect(HarvestItem.all.count).to eq 3
      item1, item2, item3 = HarvestItem.all
      expect(item1).to be_completed
      expect(item2).to be_failed
      expect(item3).to be_failed

      expect(item1.info.error).to be_nil
      expect(item2.info.error).to be_nil
      expect(item3.info.error).to be_nil

      expect(item1.info.to_h[:validations]).to match []
      expect(item2.info.to_h[:validations]).to match [
        {
          name: :overlapping_files_in_harvest,
          status: :not_fixable,
          message: /An overlap was detected.* overlaps with.*/m
        }
      ]
      expect(item3.info.to_h[:validations]).to match [
        {
          name: :overlapping_files_in_harvest,
          status: :not_fixable,
          message: /An overlap was detected.* overlaps with.*/m
        }
      ]

      # the first recording was added without failure
      expect(AudioRecording.count).to eq 1
    end
  end
end
