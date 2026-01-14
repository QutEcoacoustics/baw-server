describe 'sites/group_by' do
  create_audio_recordings_hierarchy

  before do
    create_list(:audio_event, 5, audio_recording: audio_recording)

    @site2 = create(
      :site,
      :with_lat_long,
      region:,
      projects: [project],
      obfuscated_latitude: site.latitude + 0.5,
      obfuscated_longitude: site.longitude + 0.5
    )
    second_recording = create(:audio_recording, site: @site2)
    create_list(:audio_event, 3, audio_recording: second_recording)
  end

  it 'can return a result' do
    get '/sites/group_by/audio_events', **api_headers(owner_token)

    expect_success

    expect(api_data).to match(
      array_including(
        a_hash_including(
          site_id: site.id,
          audio_event_count: 5,
          latitude: site.latitude,
          longitude: site.longitude,
          location_obfuscated: false
        ),
        a_hash_including(
          site_id: @site2.id,
          audio_event_count: 3,
          latitude: @site2.latitude,
          longitude: @site2.longitude,
          location_obfuscated: false
        )
      )
    )
  end

  it 'returns obfuscated coordinates for non-owners' do
    get '/sites/group_by/audio_events', **api_headers(reader_token)

    expect_success

    expect(api_data).to match(
      array_including(
        a_hash_including(
          site_id: site.id,
          location_obfuscated: true,
          latitude: site.obfuscated_latitude || site.latitude,
          longitude: site.obfuscated_longitude || site.longitude
        ),
        a_hash_including(
          site_id: @site2.id,
          location_obfuscated: true,
          latitude: @site2.obfuscated_latitude,
          longitude: @site2.obfuscated_longitude
        )
      )
    )
  end
end
