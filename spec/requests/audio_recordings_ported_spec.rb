# frozen_string_literal: true

# Provenance: migrated from spec/acceptance/audio_recordings_spec.rb.

describe 'Audio recording harvesting', type: :request do
  create_audio_recordings_hierarchy

  let(:collection_path) { "/projects/#{project.id}/sites/#{site.id}/audio_recordings" }
  let(:attributes) {
    attributes_for(:audio_recording, site_id: site.id, uploader_id: writer_user.id)
  }

  describe 'resuming an aborted upload' do
    it 'reuses the aborted recording, resets its status and replaces its notes' do
      original = create(:audio_recording, **attributes, creator: writer_user, status: :aborted)
      notes = { test: ['something'] }

      expect {
        post collection_path, params: { audio_recording: attributes.merge(notes:) },
          **api_with_body_headers(harvester_token)
      }.not_to change(AudioRecording, :count)

      expect(response).to have_http_status(:created)
      expect(api_data[:id]).to eq(original.id)
      expect(api_data).to have_key(:bit_rate_bps)
      expect(original.reload.status).to eq('new')
      expect(original.notes).to eq(notes)
    end
  end

  it 'rejects a two-second recording without persisting it' do
    expect {
      post collection_path, params: { audio_recording: attributes.merge(duration_seconds: 2.0) },
        **api_with_body_headers(harvester_token)
    }.not_to change(AudioRecording, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(api_result.dig(:meta, :error, :info)).to have_key(:duration_seconds)
    expect(response_body).to include('Record could not be saved')
  end

  describe 'overlapping uploads' do
    # Offsets are relative to noon UTC; the final two cases retain the original
    # timezone/fractional-duration regressions instead of rounding the fixtures.
    [
      { name: 'touching boundaries', start: 0, duration: 60, existing: [[60, 60]], expected: [60, [60]] },
      { name: 'trims the end of the existing recording', date: '2000-01-02T12:00:00Z', start: 59, duration: 60,
        existing: [[0, 60]], expected: [60, [59]] },
      { name: 'trims the end of the new recording', date: '2000-01-03T12:00:00Z', start: 0, duration: 60,
        existing: [[59, 60]], expected: [59, [60]] },
      { name: 'rejects ten seconds at the start of an existing recording',
        date: '2000-01-04T12:00:00Z', start: 0, duration: 60,
        existing: [[50, 60]], expected: [nil, [60]] },
      { name: 'trims the new recording between two existing recordings',
        date: '2000-01-05T12:00:00Z', start: 62, duration: 60,
        existing: [[0, 60], [120, 60]], expected: [58, [60, 60]] },
      { name: 'trims both the new and an existing recording',
        date: '2000-01-06T12:00:00Z', start: 59, duration: 62,
        existing: [[0, 60], [120, 60]], expected: [61, [59, 60]] },
      { name: 'rejects ten seconds between two existing recordings',
        date: '2000-01-07T12:00:00Z', start: 50, duration: 70,
        existing: [[0, 60], [120, 60]], expected: [nil, [60, 60]] },
      { name: 'keeps separated fractional-length recordings unchanged',
        date: '2014-10-23T00:01:00+10:00', start: 0, duration: 7200.003,
        existing: [[-14_400, 7200.003]], expected: [7200.003, [7200.003]] },
      { name: 'corrects the 0.003-second overlap',
        date: '2015-01-01T20:48:00+10:00', start: 0, duration: 7200.003,
        existing: [[7200, 7200.003]], expected: [7200.0, [7200.003]] }
    ].each do |scenario|
      it scenario[:name] do
        base = Time.zone.parse(scenario.fetch(:date, '2000-01-01T12:00:00Z'))
        existing = scenario[:existing].map { |offset, duration|
          create(:audio_recording, site:, creator: writer_user, uploader: writer_user,
            recorded_date: base + offset, duration_seconds: duration, status: :ready)
        }
        posted = attributes.merge(
          recorded_date: (base + scenario[:start]).iso8601(3),
          duration_seconds: scenario[:duration]
        )
        expected_duration, existing_durations = scenario[:expected]
        count = AudioRecording.count

        post collection_path, params: { audio_recording: posted }, **api_with_body_headers(harvester_token)

        if expected_duration
          expect(response).to have_http_status(:created)
          expect(api_data).to have_key(:bit_rate_bps)
          expect(api_data[:duration_seconds]).to eq(expected_duration)
          expect(AudioRecording.count).to eq(count + 1)
          created = AudioRecording.find(api_data[:id])
          expect(created.recorded_date).to eq(base + scenario[:start])
          expect(created.duration_seconds).to eq(expected_duration)
          if expected_duration != scenario[:duration]
            expect(created.notes).to have_key(:duration_adjustment_for_overlap)
          end
        else
          expect(response).to have_http_status(:unprocessable_content)
          overlap = api_result.dig(:meta, :error, :info, :overlap)
          expect(overlap[:count]).to be_positive
          expect(overlap[:items].first).to have_key(:overlap_amount)
          expect(AudioRecording.count).to eq(count)
          expect(AudioRecording.exists?(file_hash: posted[:file_hash])).to be(false)
        end

        existing.each_with_index do |recording, index|
          expect(recording.reload.recorded_date).to eq(base + scenario[:existing][index][0])
          expect(recording.duration_seconds).to eq(existing_durations[index])
          if existing_durations[index] != scenario[:existing][index][1]
            expect(recording.notes).to have_key(:duration_adjustment_for_overlap)
          end
        end
      end
    end
  end

  describe 'checking uploader permissions' do
    it 'returns no content when the harvester checks a writer' do
      get "#{collection_path}/check_uploader/#{writer_user.id}", **api_headers(harvester_token)

      expect(response).to have_http_status(:no_content)
      expect_empty_body
      expect(response.headers['Content-Type']).to be_nil
    end

    it 'explains why a writer cannot check uploader permissions' do
      get "#{collection_path}/check_uploader/#{writer_user.id}", **api_headers(writer_token)

      expect(api_result.dig(:meta, :error, :info)).to include(project_id: project.id)
      expect(response_body).to include('only harvester can check uploader permissions')
    end

    it 'reports the project and user when the uploader has no access' do
      get "#{collection_path}/check_uploader/#{no_access_user.id}", **api_headers(harvester_token)

      expect(response).to have_http_status(:forbidden)
      expect(api_result.dig(:meta, :error, :info)).to include(project_id: project.id, user_id: no_access_user.id)
      expect(response_body).to include('uploader does not exist or does not have access to this project')
    end
  end

  describe 'updating upload status' do
    let(:status_attributes) {
      { file_hash: audio_recording.file_hash, uuid: audio_recording.uuid, status: 'uploading' }
    }

    it 'persists the new status and returns an empty response' do
      put "/audio_recordings/#{audio_recording.id}/update_status",
        params: status_attributes, **api_with_body_headers(harvester_token)

      expect(response).to have_http_status(:no_content)
      expect_empty_body
      expect(response.headers['Content-Type']).to be_nil
      expect(audio_recording.reload.status).to eq('uploading')
    end

    it 'reports the requested and stored file hashes without changing status' do
      put "/audio_recordings/#{audio_recording.id}/update_status",
        params: status_attributes.merge(file_hash: 'blah'), **api_with_body_headers(harvester_token)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_body).to include('Incorrect file hash')
      expect(api_result.dig(:meta, :error, :info, :audio_recording, :file_hash))
        .to eq(stored: audio_recording.file_hash, request: 'blah')
      expect(audio_recording.reload.status).to eq('ready')
    end

    it 'reports the requested and stored UUIDs without changing status' do
      put "/audio_recordings/#{audio_recording.id}/update_status",
        params: status_attributes.merge(uuid: 'blah'), **api_with_body_headers(harvester_token)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_body).to include('Incorrect uuid')
      expect(api_result.dig(:meta, :error, :info, :audio_recording, :uuid))
        .to eq(stored: audio_recording.uuid, request: 'blah')
      expect(audio_recording.reload.status).to eq('ready')
    end

    it 'reports available statuses for an unknown status without changing the recording' do
      put "/audio_recordings/#{audio_recording.id}/update_status",
        params: status_attributes.merge(status: 'does_not_exist'), **api_with_body_headers(harvester_token)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_body).to include('Status does_not_exist is not in available status list')
      expect(api_result.dig(:meta, :error, :info, :available_statuses))
        .to match_array(AudioRecording::AVAILABLE_STATUSES)
      expect(audio_recording.reload.status).to eq('ready')
    end
  end

  describe 'worker metadata updates' do
    it 'updates all standard properties' do
      changed = {
        media_type: 'audio/webm', sample_rate_hertz: 456, channels: 20,
        bit_rate_bps: 123, data_length_bytes: 789, duration_seconds: 70.0
      }

      put "/audio_recordings/#{audio_recording.id}", params: { audio_recording: changed },
        **api_with_body_headers(harvester_token)

      expect_success
      expect(api_data).to include(changed)
      expect(audio_recording.reload.attributes.symbolize_keys).to include(changed)
    end

    it 'updates the file hash on its own' do
      file_hash = attributes[:file_hash]

      put "/audio_recordings/#{audio_recording.id}", params: { audio_recording: { file_hash: } },
        **api_with_body_headers(harvester_token)

      expect_success
      expect(api_data[:duration_seconds]).to eq(audio_recording.duration_seconds)
      expect(audio_recording.reload.file_hash).to eq(file_hash)
    end

    it 'rejects a file hash combined with metadata without changing the recording' do
      original = audio_recording.attributes
      changed = {
        media_type: 'audio/webm', sample_rate_hertz: 456, channels: 20,
        bit_rate_bps: 123, data_length_bytes: 789, duration_seconds: 70.0,
        file_hash: 'SHA256::something'
      }

      put "/audio_recordings/#{audio_recording.id}", params: { audio_recording: changed },
        **api_with_body_headers(harvester_token)

      expect(response).to have_http_status(:unprocessable_content)
      expect(api_result.dig(:meta, :error, :info)).to have_key(:file_hash)
      expect(audio_recording.reload.attributes).to match_attributes(original)
    end
  end

  describe 'filtering' do
    let(:matching_filter) {
      { and: { site_id: { less_than: 123_456 }, duration_seconds: { not_eq: 40 } } }
    }

    it 'returns recordings matching a combined filter' do
      post '/audio_recordings/filter', params: { filter: matching_filter }, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data.first[:id]).to eq(audio_recording.id)
    end

    it 'returns no recordings when nothing matches' do
      body = { filter: { and: { channels: { lteq: 2, gt: 0 }, media_type: { eq: 'audio/wav' } } } }

      post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(0)
    end

    it 'pages beyond the last result' do
      body = { filter: matching_filter, paging: { page: 2, items: 30 } }

      post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(0)
      expect_has_paging(page: 2, items: 30, total: 1)
      expect(api_result.dig(:meta, :paging, :current))
        .to end_with('/audio_recordings/filter?direction=desc&items=30&order_by=recorded_date&page=1')
    end

    it 'sorts by a requested field' do
      body = { filter: matching_filter, sorting: { order_by: :channels, direction: :asc } }

      post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data.first[:id]).to eq(audio_recording.id)
      expect_has_sorting(order_by: 'channels', direction: 'asc')
      expect(api_result.dig(:meta, :paging, :current))
        .to end_with('/audio_recordings/filter?direction=asc&items=25&order_by=channels&page=1')
    end
  end
end
