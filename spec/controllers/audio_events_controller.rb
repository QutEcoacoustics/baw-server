require 'spec_helper'

describe AudioEventsController do
  ################################
  # csv filters
  ################################
  context 'csv download' do

    #header 'Accept', 'application/json'
    #header 'Content-Type', 'application/json'

    get '/audio_recordings/:audio_recording_id/audio_events/download' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
      let(:authentication_token) { writer_token }
      standard_request('CSV AUDIO RECORDING (as writer)', 200, '0/start_time_seconds', true)
    end

    get '/audio_recordings/:audio_recording_id/audio_events/download' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
      let(:authentication_token) { reader_token }
      standard_request('CSV AUDIO RECORDING (as reader)', 200, '0/start_time_seconds', true)
    end

    get '/audio_recordings/:audio_recording_id/audio_events/download' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
      let(:authentication_token) { admin_token }
      standard_request('CSV AUDIO RECORDING (as admin)', 200, '0/start_time_seconds', true)
    end

    get '/audio_recordings/:audio_recording_id/audio_events/download' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
      let(:authentication_token) { unconfirmed_token }
      standard_request('CSV AUDIO RECORDING (as unconfirmed user)', 401, nil, true)
    end

    get '/projects/:project_id/audio_events/download' do
      parameter :project_id, 'Requested project id (in path/route)', required: true
      let(:authentication_token) { writer_token }
      standard_request('CSV PROJECT (as writer)', 200, '0/start_time_seconds', true)
    end

    get '/projects/:project_id/audio_events/download' do
      parameter :project_id, 'Requested project id (in path/route)', required: true
      let(:authentication_token) { reader_token }
      standard_request('CSV PROJECT (as reader)', 200, '0/start_time_seconds', true)
    end

    get '/projects/:project_id/audio_events/download' do
      parameter :project_id, 'Requested project id (in path/route)', required: true
      let(:authentication_token) { admin_token }
      standard_request('CSV PROJECT (as admin)', 200, '0/start_time_seconds', true)
    end

    get '/projects/:project_id/audio_events/download' do
      parameter :project_id, 'Requested project id (in path/route)', required: true
      let(:authentication_token) { unconfirmed_token }
      standard_request('CSV PROJECT (as unconfirmed user)', 401, nil, true)
    end

    get '/projects/:project_id/sites/:site_id/audio_events/download' do
      parameter :project_id, 'Requested project id (in path/route)', required: true
      parameter :site_id, 'Requested site id (in path/route)', required: true
      let(:authentication_token) { writer_token }
      standard_request('CSV SITE (as writer)', 200, '0/start_time_seconds', true)
    end

    get '/projects/:project_id/audio_events/download' do
      parameter :project_id, 'Requested project id (in path/route)', required: true
      parameter :site_id, 'Requested site id (in path/route)', required: true
      let(:authentication_token) { reader_token }
      standard_request('CSV SITE (as reader)', 200, '0/start_time_seconds', true)
    end

    get '/projects/:project_id/audio_events/download' do
      parameter :project_id, 'Requested project id (in path/route)', required: true
      parameter :site_id, 'Requested site id (in path/route)', required: true
      let(:authentication_token) { admin_token }
      standard_request('CSV SITE (as admin)', 200, '0/start_time_seconds', true)
    end

    get '/projects/:project_id/audio_events/download' do
      parameter :project_id, 'Requested project id (in path/route)', required: true
      parameter :site_id, 'Requested site id (in path/route)', required: true
      let(:authentication_token) { unconfirmed_token }
      standard_request('CSV SITE (as unconfirmed user)', 401, nil, true)
    end
  end
end