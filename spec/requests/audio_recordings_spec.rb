# frozen_string_literal: true

describe '/audio_recordings' do
  create_entire_hierarchy

  context 'when shown, provides a timezone along with recorded date' do
    example 'when the timezone is present in the site' do
      site.tzinfo_tz = 'Australia/Sydney'
      site.save!

      get "/audio_recordings/#{audio_recording.id}", headers: api_request_headers(reader_token)
      expect(response).to have_http_status(:success)
      expect(api_result).to include(data: hash_including({
        recorded_date_timezone: 'Australia/Sydney'
      }))
    end

    example 'when the timezone is nil in the site' do
      site.tzinfo_tz = nil
      site.save!

      get "/audio_recordings/#{audio_recording.id}", headers: api_request_headers(reader_token)
      expect(response).to have_http_status(:success)
      expect(api_result).to include(data: hash_including({
        recorded_date_timezone: nil
      }))
    end
  end
end
