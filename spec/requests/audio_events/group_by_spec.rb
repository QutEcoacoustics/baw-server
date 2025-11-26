describe 'audio_events/group_by' do
  create_audio_recordings_hierarchy

  let!(:tag) { create(:tag, text: 'kookaburra', creator: owner_user) }
  let!(:site2) { create(:site, :with_lat_long, region:, projects: [project]) }

  before do
    create_list(:audio_event, 5, audio_recording: audio_recording)
    other_event = create(:audio_event, audio_recording:, creator: owner_user)
    create(:tagging, tag:, audio_event: other_event, creator: owner_user)

    second_recording = create(:audio_recording, site: site2)
    create_list(:audio_event, 3, audio_recording: second_recording)
  end

  def check_locations(data, obfuscated)
    site1_result = data[0]
    site2_result = data[1]

    aggregate_failures do
      expect(site1_result[:site_id]).to eq site.id
      expect(site1_result[:location_obfuscated]).to eq obfuscated
      expect(site1_result[:latitude]).to eq(obfuscated ? site.obfuscated_latitude : site.latitude)
      expect(site1_result[:longitude]).to eq(obfuscated ? site.obfuscated_longitude : site.longitude)

      expect(site2_result[:site_id]).to eq site2.id
      expect(site2_result[:location_obfuscated]).to eq obfuscated
      expect(site2_result[:latitude]).to eq(obfuscated ? site2.obfuscated_latitude : site2.latitude)
      expect(site2_result[:longitude]).to eq(obfuscated ? site2.obfuscated_longitude : site2.longitude)
    end
  end

  it 'can return a result' do
    get '/audio_events/group_by/sites', **api_headers(owner_token)

    expect_success

    expect(api_data).to match [
      a_hash_including(
        site_id: site.id,
        region_id: region.id,
        project_ids: [
          project.id
        ],
        audio_event_count: 6
      ),
      a_hash_including(
        site_id: site2.id,
        region_id: region.id,
        project_ids: [
          project.id
        ],
        audio_event_count: 3
      )
    ]

    check_locations(api_data, false)
  end

  it 'can return a result with filter' do
    params = {
      filter: {
        'tags.text': { eq: tag.text }
      }
    }

    get '/audio_events/group_by/sites', params:, **api_headers(owner_token)

    expect_success

    expect(api_data).to match [
      a_hash_including(
        site_id: site.id,
        region_id: region.id,
        project_ids: [
          project.id
        ],
        audio_event_count: 1
      )
    ]
  end

  it 'preserves obfuscated locations' do
    get '/audio_events/group_by/sites', **api_headers(reader_token)

    expect_success

    check_locations(api_data, true)
  end
end
