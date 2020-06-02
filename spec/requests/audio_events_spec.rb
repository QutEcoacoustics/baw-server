require 'rails_helper'
require 'rspec/mocks'

describe "Audio Events" do

  create_entire_hierarchy

  # projects update/create actions expect payload from html form as well as json
  describe 'Downloading Csv' do

    before(:each) do
      @env ||= {}
      @env['HTTP_AUTHORIZATION'] = admin_token

      @download_url = "/audio_recordings/#{audio_recording.id}/audio_events/download"
    end

    it 'downloads csv file with no leading spaces in headers' do

      get @download_url, nil, @env
      expect(response).to have_http_status(200)
      column_headers = "audio_event_id,audio_recording_id,audio_recording_uuid,audio_recording_start_date_utc_00_00,"+
          "audio_recording_start_time_utc_00_00,audio_recording_start_datetime_utc_00_00,event_created_at_date_utc_00_00,"+
          "event_created_at_time_utc_00_00,event_created_at_datetime_utc_00_00,projects,site_id,site_name,"+
          "event_start_date_utc_00_00,event_start_time_utc_00_00,event_start_datetime_utc_00_00,event_start_seconds,"+
          "event_end_seconds,event_duration_seconds,low_frequency_hertz,high_frequency_hertz,is_reference,created_by,"+
          "updated_by,common_name_tags,common_name_tag_ids,species_name_tags,species_name_tag_ids,other_tags,"+
          "other_tag_ids,listen_url,library_url\n"
      expect(response.body).to start_with(column_headers)
    end

  end

end



