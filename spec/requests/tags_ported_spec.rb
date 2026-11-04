# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/tags_spec.rb.

describe 'Tag filtering ported from acceptance', type: :request do
  create_audio_recordings_hierarchy
  prepare_tag
  let!(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }
  let!(:excluded_tag) {
    create(:tag, creator: admin_user, text: 'unrelated', type_of_tag: 'sounds_like', retired: true)
  }

  prepare_audio_events_tags

  it 'filters retired tags and projects only the requested fields' do
    fields = ['id', 'text', 'is_taxonomic', 'retired']
    filter = { retired: { eq: false } }

    post '/tags/filter', params: { filter:, projection: { include: fields } },
      **api_with_body_headers(reader_token)

    expect_success
    expect(api_data).to eq([{
      id: tag.id, text: tag.text, is_taxonomic: false, retired: false
    }])
    expect_has_filter(filter)
    expect_has_projection(only: fields)
  end

  it 'filters by tag type without embedding taggings' do
    filter = { type_of_tag: { eq: 'general' } }
    post '/tags/filter', params: { filter: }, **api_with_body_headers(reader_token)

    expect_success
    expect_number_of_items(1)
    expect(api_data.first).to include(id: tag.id, type_of_tag: 'general')
    expect(api_data.first).not_to have_key(:taggings)
    expect_has_filter(filter)
  end

  it 'filters text using contains and echoes the filter' do
    filter = { text: { contains: 'tag text' } }
    post '/tags/filter', params: { filter: }, **api_with_body_headers(writer_token)

    expect_success
    expect_number_of_items(1)
    expect(api_data.first).to include(id: tag.id, text: tag.text)
    expect(tag.text).to include('tag text')
    expect_has_filter(filter)
  end

  ['audio_events.id', 'AudioEvents.Id'].each do |field|
    it "filters the associated audio event using #{field} and normalizes its name" do
      ids = [audio_event.id + 9999, audio_event.id]
      post '/tags/filter', params: { filter: { field => { in: ids } } },
        **api_with_body_headers(writer_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data.first).to include(id: tag.id, text: tag.text)
      expect_has_filter('audio_events.id': { in: ids })
    end
  end

  it 'scopes the nested index to the requested audio event' do
    get "/audio_recordings/#{audio_recording.id}/audio_events/#{audio_event.id}/tags",
      **api_headers(reader_token)

    expect_success
    expect(api_data.pluck(:id)).to eq([tag.id])
  end

  it 'also scopes the shallow index when audio event query parameters are supplied' do
    get '/tags', params: { audio_recording_id: audio_recording.id, audio_event_id: audio_event.id },
      **api_headers(reader_token)

    expect_success
    expect(api_data.pluck(:id)).to eq([tag.id])
  end
end
