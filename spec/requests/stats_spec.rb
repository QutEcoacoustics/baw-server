# frozen_string_literal: true

describe '/stats' do
  create_audio_recordings_hierarchy
  prepare_project
  prepare_region
  prepare_site
  prepare_audio_event
  prepare_tag
  prepare_audio_events_tags
  prepare_dataset
  create_anon_hierarchy
  let!(:reference_event) { FactoryBot.create(:audio_event, is_reference: true) }

  it 'can fetch stats' do
    get '/stats'

    expect_success
    expect(api_data).to match({
      summary: {
        users_online: 0,
        users_total: 10,
        online_window_start: an_instance_of(String),
        projects_total: 1,
        regions_total: 1,
        sites_total: 1,
        annotations_total: 2,
        annotations_total_duration: 2.0,
        annotations_recent: 2,
        audio_recordings_total: 3,
        audio_recordings_recent: 3,
        audio_recordings_total_duration: 180_000.0,
        audio_recordings_total_size: 11_400,
        tags_total: 1,
        tags_applied_total: 1,
        tags_applied_unique_total: 1
      },
      recent: {
        audio_recording_ids: [2],
        audio_event_ids: [reference_event.id]
      }
    })
  end
end
