describe 'sites/group_by' do
  create_audio_recordings_hierarchy

  before do
    create_list(:audio_event, 5, audio_recording: audio_recording)
    site2 = create(:site, :with_lat_long, region:, projects: [project])
    second_recording = create(:audio_recording, site: site2)
    create_list(:audio_event, 3, audio_recording: second_recording)
  end

  it 'can return a result' do
    get '/sites/group_by/audio_events', **api_headers(owner_token)

    expect_success

    expect(api_data).to eq []
  end
end
