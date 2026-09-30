# frozen_string_literal: true

describe 'Audio event statistics' do
  create_audio_recordings_hierarchy

  let(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }
  let(:tag) { create(:tag, creator: writer_user) }

  before do
    second_event = create(:audio_event, audio_recording:, creator: writer_user)

    create(:tagging, audio_event: audio_event, tag: tag, creator: writer_user)
    create(:tagging, audio_event: second_event, tag: tag, creator: writer_user)
  end

  it 'returns audio event statistics' do
    post '/audio_events/stats', **api_with_body_headers(writer_token)

    expect(response).to have_http_status(:ok)
    expect(api_data).to eq(count: 2, taggings_count: 2)
  end

  it 'counts all taggings when an event has multiple tags' do
    second_tag = create(:tag, creator: writer_user)
    create(:tagging, audio_event: audio_event, tag: second_tag, creator: writer_user)

    post '/audio_events/stats', **api_with_body_headers(writer_token)

    expect(api_data).to eq(count: 2, taggings_count: 3)
  end

  it 'calculates stats from filtered events' do
    create(:audio_event, audio_recording:, creator: writer_user, is_reference: true)
    filter = {
      filter: {
        or: {
          id: { eq: audio_event.id },
          is_reference: { eq: true }
        }
      }
    }

    post '/audio_events/stats', params: filter, **api_with_body_headers(writer_token)

    expect(api_data).to eq(count: 2, taggings_count: 1)
  end

  it 'returns zero totals when no events match' do
    filter = { filter: { id: { eq: -1 } } }

    post '/audio_events/stats', params: filter, **api_with_body_headers(writer_token)

    expect(api_data).to eq(count: 0, taggings_count: 0)
  end

  it 'scopes nested statistics to the requested recording' do
    other_recording = create(:audio_recording, site:, creator: writer_user)
    create(:audio_event_using_tag, audio_recording: other_recording, creator: writer_user, tag:)

    post "/audio_recordings/#{other_recording.id}/audio_events/stats",
      params: body, **api_with_body_headers(writer_token)

    expect(api_data).to eq(count: 1, taggings_count: 1)
  end
end
