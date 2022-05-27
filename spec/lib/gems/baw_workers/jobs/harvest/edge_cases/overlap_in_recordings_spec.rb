# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe 'HarvestJob can deal with overlaps', :clean_by_truncation do
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

  it 'can repair minor overlaps' do
    # create two recordings that overlap with the target file in a minor way
    duration = audio_file_mono_29_duration_seconds
    overlap = 4.0

    start1 = Time.new(2022, 1, 1, 0, 0, 0, '+00:00')
    start2 = start1 + (duration - overlap)
    start3 = start2 + (duration - overlap)

    a1 = create(:audio_recording, recorded_date: start1, duration_seconds: duration, site_id: site.id)
    # we're going to harvest the file that's in the middle
    a3 = create(:audio_recording, recorded_date: start3, duration_seconds: duration, site_id: site.id)

    # copy in a file fixture to harvest
    @paths = copy_fixture_to_harvest_directory(
      Fixtures.audio_file_mono29,
      harvest,
      target_name: "#{start2.strftime('%Y%m%d-%H%M%S%z')}.wav"
    )

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

    # the latest audio recording is the one we just added
    a1.reload
    a3.reload
    a2 = AudioRecording.last
    expect(a2.status).to eq AudioRecording::STATUS_READY

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
    # create two recordings that overlap with the target file in a minor way
    duration = audio_file_mono_29_duration_seconds
    overlap = 20.0

    start1 = Time.new(2022, 1, 1, 0, 0, 0, '+00:00')
    start2 = start1 + (duration - overlap)
    start3 = start2 + (duration - overlap)

    a1 = create(:audio_recording, recorded_date: start1, duration_seconds: duration, site_id: site.id)
    # we're going to harvest the file that's in the middle
    a3 = create(:audio_recording, recorded_date: start3, duration_seconds: duration, site_id: site.id)

    # copy in a file fixture to harvest
    @paths = copy_fixture_to_harvest_directory(
      Fixtures.audio_file_mono29,
      harvest,
      target_name: "#{start2.strftime('%Y%m%d-%H%M%S%z')}.wav"
    )

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
    expect(item.info.error).to be_nil
    expect(item.info.to_h[:validations]).to match [
      {
        name: :overlapping_files,
        status: :not_fixable,
        message: /overlaps with the following audio recordings/
      }
    ]

    # no new recordings should have been added
    expect(AudioRecording.count).to eq 2
    a1.reload
    a3.reload

    aggregate_failures do
      # recordings should be unaffected
      expect(a1.duration_seconds.to_f).to be_within(0.01).of(duration)
      expect(a3.duration_seconds.to_f).to be_within(0.01).of(duration)
    end
  end
end
