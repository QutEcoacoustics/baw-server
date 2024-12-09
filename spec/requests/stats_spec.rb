# frozen_string_literal: true

describe '/stats' do
  create_audio_recordings_hierarchy
  prepare_project
  prepare_region
  prepare_site
  prepare_provenance
  prepare_script
  prepare_analysis_job
  prepare_analysis_jobs_item
  prepare_audio_event_import
  prepare_audio_event_import_file
  prepare_audio_event
  prepare_tag
  prepare_audio_events_tags
  prepare_dataset
  create_anon_hierarchy
  let!(:reference_event) { create(:audio_event, audio_recording:, is_reference: true) }

  it 'can fetch stats' do
    # anonymous request
    get '/stats'

    expect_success
    expect(api_data).to match({
      summary: {
        # test randomness sometimes means we don't know how many people are 'online'
        users_online: an_instance_of(Integer),
        users_total: User.count,
        online_window_start: an_instance_of(String),
        projects_total: 2,
        regions_total: 1,
        sites_total: 2,
        annotations_total: 2,
        annotations_total_duration: 2.0,
        annotations_recent: 2,
        audio_recordings_total: 2,
        audio_recordings_recent: 2,
        audio_recordings_total_duration: 120_000.0,
        audio_recordings_total_size: 7600,
        tags_total: 1,
        tags_applied_total: 1,
        tags_applied_unique_total: 1
      },
      recent: {
        audio_recording_ids: [audio_recording_anon.id],
        audio_event_ids: [reference_event.id]
      }
    })
  end
end
