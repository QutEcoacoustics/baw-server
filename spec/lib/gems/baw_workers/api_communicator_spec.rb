# frozen_string_literal: true

require 'workers_helper'

describe BawWorkers::ApiCommunicator do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  let(:api) { BawWorkers::Config.api_communicator }
  let(:api_different) {
    BawWorkers::ApiCommunicator.new(
      BawWorkers::Config.logger_worker,
      BawWorkers::Settings.api.dup.merge('password' => 'different password'),
      BawWorkers::Settings.endpoints
    )
  }

  context 'login request' do
    it 'should succeed with valid credentials' do
      auth_token_server = 'auth_token_string'
      email = 'address@example.com'
      password = 'different password'
      endpoint_login = default_uri + BawWorkers::Settings.endpoints.login
      body = get_api_security_request(email, password)
      login_request = stub_request(:post, endpoint_login)
                      .with(body: body)
                      .to_return(body: get_api_security_response(email, auth_token_server).to_json)

      security_info = api_different.request_login

      expect(login_request).to have_been_made.once
      expect(security_info).to_not be_blank
      expect(security_info[:auth_token]).to eq(auth_token_server)
    end

    it 'should throw error with invalid credentials' do
      auth_token = 'auth_token_string'
      email = 'address@example.com'
      password = 'different password'
      endpoint_login = default_uri + BawWorkers::Settings.endpoints.login

      login_request = stub_request(:post, endpoint_login)
                      .with(body: get_api_security_request(email, 'password'))
                      .to_return(body: get_api_security_response(email, auth_token).to_json)

      incorrect_request = stub_request(:post, endpoint_login)
                          .with(body: get_api_security_request(email, password))
                          .to_return(status: 403)

      security_info = api_different.request_login

      expect(login_request).not_to have_been_made
      expect(incorrect_request).to have_been_made.once
      expect(security_info[:cookies]).to be_blank
      expect(security_info[:auth_token]).to be_blank
    end

  end

  context 'sending requests' do

    it 'should successfully send a basic request' do
      basic_request = stub_request(:get, default_uri)
      api.send_request('send basic get request', :get, host, port, '/')
      expect(basic_request).to have_been_made.once
    end

    it 'should fail on bad request' do
      endpoint_access = default_uri + '/does_not_exist'
      expect {
        api.send_request('will fail', :get, host, port, endpoint_access)
      }.to raise_error
    end
  end

  context 'check project access ' do
    it 'should succeed with valid credentials' do
      auth_token = 'auth_token_string'
      endpoint_access = default_uri + BawWorkers::Settings.endpoints.audio_recording_uploader
      body = {}
      access_request = stub_request(:get, "#{default_uri}/projects/1/sites/1/audio_recordings/check_uploader/1")
                       .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string"', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                       .to_return(status: 204)

      expect(api.check_uploader_project_access(1, 1, 1, auth_token: auth_token)).to be_truthy
      expect(access_request).to have_been_made.once
    end

    it 'should fail with invalid credentials' do
      auth_token = 'auth_token_string_wrong'
      endpoint_access = default_uri + BawWorkers::Settings.endpoints.audio_recording_uploader
      body = {}
      access_request = stub_request(:get, "#{default_uri}/projects/1/sites/1/audio_recordings/check_uploader/1")
                       .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string_wrong"', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                       .to_return(status: 403)

      expect(api.check_uploader_project_access(1, 1, 1, auth_token: auth_token)).to be_falsey
      expect(access_request).to have_been_made.once
    end

  end

  context 'update audio recording metadata' do
    it 'should succeed with valid credentials' do
      auth_token = 'auth_token_string'
      endpoint = default_uri + BawWorkers::Settings.endpoints.audio_recording_update_status
      body = {}
      access_request = stub_request(:put, "#{default_uri}/audio_recordings/1")
                       .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string"',
                                        'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                       .to_return(status: 204)

      expect(api.update_audio_recording_details(
               'description',
               'file',
               1,
               {},
               { auth_token: auth_token }
             )).to be_truthy
      expect(access_request).to have_been_made.once
    end

    it 'should fail with invalid credentials' do
      auth_token = 'auth_token_string_wrong'
      endpoint = default_uri + BawWorkers::Settings.endpoints.audio_recording_update_status
      body = {}
      access_request = stub_request(:put, "#{default_uri}/audio_recordings/1")
                       .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string_wrong"',
                                        'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                       .to_return(status: 403)

      expect(api.update_audio_recording_details(
               'description',
               'file',
               1,
               {},
               { auth_token: auth_token }
             )).to be_falsey
      expect(access_request).to have_been_made.once
    end

  end

  context 'analysis jobs items' do
    context 'get analysis jobs item status' do
      it 'should succeed with valid credentials' do
        auth_token = 'auth_token_string'
        access_request = stub_request(:get, "#{default_uri}/analysis_jobs/1/audio_recordings/123")
                         .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string"',
                                          'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                         .to_return(status: 200, body: '{
                    "meta": {
                        "status": 200,
                        "message": "OK"
                    },
                    "data": {
                        "id": 88,
                        "analysis_job_id": 73,
                        "audio_recording_id": 103,
                        "queue_id": "68eade5943c5bf79a6ae734adb49967b",
                        "status": "queued",
                        "created_at": "2016-09-05T05:36:22.242+02:00",
                        "queued_at": "2016-09-05T05:36:22.338+02:00",
                        "work_started_at": null,
                        "completed_at": null
                    }
                }')

        expect(api.get_analysis_jobs_item_status(
                 1,
                 123,
                 auth_token: auth_token
               )).to include({

                             })
        expect(access_request).to have_been_made.once
      end

      it 'should fail with invalid credentials' do
        auth_token = 'auth_token_string_wrong'
        access_request = stub_request(:get, "#{default_uri}/analysis_jobs/1/audio_recordings/123")
                         .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string_wrong"',
                                          'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                         .to_return(status: 403)

        expect(api.get_analysis_jobs_item_status(
                 1,
                 123,
                 auth_token: auth_token
               )).to include(
                 response_json: nil,
                 status: nil
               )
        expect(access_request).to have_been_made.once
      end
    end

    context 'update analysis jobs item status' do
      it 'should succeed with valid credentials' do
        auth_token = 'auth_token_string'
        access_request = stub_request(:put, "#{default_uri}/analysis_jobs/1/audio_recordings/123")
                         .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string"',
                                          'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                         .to_return(status: 200, body: '{
                    "meta": {
                        "status": 200,
                        "message": "OK"
                    },
                    "data": {
                        "id": 88,
                        "analysis_job_id": 73,
                        "audio_recording_id": 103,
                        "queue_id": "68eade5943c5bf79a6ae734adb49967b",
                        "status": "queued",
                        "created_at": "2016-09-05T05:36:22.242+02:00",
                        "queued_at": "2016-09-05T05:36:22.338+02:00",
                        "work_started_at": null,
                        "completed_at": null
                    }
                }')

        expect(api.update_analysis_jobs_item_status(
                 1,
                 123,
                 :successful,
                 auth_token: auth_token
               )).to include({

                             })
        expect(access_request).to have_been_made.once
      end

      it 'should fail with invalid credentials' do
        auth_token = 'auth_token_string_wrong'
        endpoint = default_uri + BawWorkers::Settings.endpoints.audio_recording_update_status
        body = { status: :successful }
        access_request = stub_request(:put, "#{default_uri}/analysis_jobs/1/audio_recordings/123")
                         .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string_wrong"',
                                          'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                         .to_return(status: 403)

        expect(api.update_analysis_jobs_item_status(
                 1,
                 123,
                 :successful,
                 auth_token: auth_token
               )).to include(
                 response_json: nil,
                 status: nil
               )
        expect(access_request).to have_been_made.once
      end

      it 'should throw with an invalid status' do
        auth_token = 'auth_token_string'
        expect {
          api.update_analysis_jobs_item_status(
            1,
            123,
            :new,
            auth_token: auth_token
          )
        }.to raise_error('Cannot set status to `new`')

      end
    end
  end
end
