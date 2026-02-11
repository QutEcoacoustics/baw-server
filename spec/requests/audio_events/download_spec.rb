# frozen_string_literal: true

describe '/audio_events/download' do
  create_entire_hierarchy

  it 'can filter by audio_event_import_id' do
    audio_event.update!(audio_event_import_file: nil)
    another_event = create(
      :audio_event,
      audio_recording:,
      creator: writer_user,
      audio_event_import_file:
    )

    get "/projects/#{project.id}/audio_events/download?audio_event_import_id=#{audio_event_import_file.id}",
      headers: auth_header(writer_token)

    expect_success
    lines = response.body.lines
    expect(lines.length).to eq(2) # header + 1 event
    expect(lines[1]).to start_with(another_event.id.to_s)
  end

  # projects update/create actions expect payload from html form as well as json
  describe 'Downloading Csv' do
    def download_url
      "/audio_recordings/#{audio_recording.id}/audio_events/download"
    end

    it 'downloads csv file with no leading spaces in headers' do
      get download_url, params: nil, headers: auth_header(admin_token)
      expect(response).to have_http_status(:ok)
      column_headers = 'audio_event_id,audio_recording_id,audio_recording_uuid,audio_recording_start_date_utc_00_00,' \
                       'audio_recording_start_time_utc_00_00,audio_recording_start_datetime_utc_00_00,event_created_at_date_utc_00_00,' \
                       'event_created_at_time_utc_00_00,event_created_at_datetime_utc_00_00,projects,region_id,region_name,site_id,site_name,' \
                       'event_start_date_utc_00_00,event_start_time_utc_00_00,event_start_datetime_utc_00_00,event_start_seconds,' \
                       'event_end_seconds,event_duration_seconds,low_frequency_hertz,high_frequency_hertz,score,is_reference,created_by,' \
                       'updated_by,common_name_tags,common_name_tag_ids,species_name_tags,species_name_tag_ids,other_tags,other_tag_ids,' \
                       'verifications,verification_counts,verification_correct,verification_incorrect,verification_skip,verification_unsure,' \
                       'verification_decisions,verification_consensus,audio_event_import_file_id,audio_event_import_file_name,' \
                       'audio_event_import_id,audio_event_import_name,' \
                       "listen_url,library_url\n"
      expect(response.body).to start_with(column_headers)
    end
  end

  describe 'Downloading Json' do
    def download_url
      "/audio_recordings/#{audio_recording.id}/audio_events/download.json"
    end

    it 'downloads json file as a valid columnar JSON object' do
      get download_url, params: nil, headers: auth_header(admin_token)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')

      body = response.parsed_body
      expect(body).to be_a(Hash)
      expect(body).to have_key('columns')
      expect(body).to have_key('rows')

      columns = body['columns']
      rows = body['rows']
      expect(rows.length).to eq(1)

      # Reconstruct the first row as a hash for readable assertions
      row = columns.zip(rows.first).to_h
      expect(row['audio_event_id']).to eq(audio_event.id)
      expect(row['audio_recording_id']).to eq(audio_recording.id)
      expect(row).to have_key('audio_recording_uuid')
      expect(row).to have_key('listen_url')
      expect(row).to have_key('library_url')
    end
  end
end
