require 'spec_helper'

describe BawWorkers::ApiCommunicator do
  include_context 'media_file'

  let(:api) { BawWorkers::Config.api_communicator }
  let(:api_different) {
    BawWorkers::ApiCommunicator.new(
        BawWorkers::Config.logger_worker,
        BawWorkers::Settings.api.dup.merge({'password' => 'different password'}),
        BawWorkers::Settings.endpoints)
  }
  let(:host) { 'localhost' }
  let(:port) { 3030 }
  let(:domain) { "http://#{host}:#{port}" }

  context 'login request' do
    it 'should succeed with valid credentials' do
      auth_token_server = 'auth_token_string'
      endpoint_login = domain + BawWorkers::Settings.endpoints.login
      body = {email: 'address@example.com', password: 'different password'}
      login_request = stub_request(:post, endpoint_login)
      .with(body: body)
      .to_return(body: '{"success":true,"auth_token":"'+auth_token_server+'","email":"address@example.com"}')

      auth_token = api_different.request_login

      expect(login_request).to have_been_made.once
      expect(auth_token).to_not be_blank
      expect(auth_token).to eq(auth_token_server)
    end

    it 'should throw error with invalid credentials' do
      auth_token = 'auth_token_string'
      endpoint_login = domain + BawWorkers::Settings.endpoints.login
      body = {email: 'address@example.com', password: 'different password'}

      login_request = stub_request(:post, endpoint_login)
      .with(body: {email: 'address@example.com', password: 'password'})
      .to_return(body: '{"success":true,"auth_token":"'+auth_token+'","email":"address@example.com"}')

      incorrect_request = stub_request(:post, endpoint_login)
      .with(body: {email: 'address@example.com', password: 'different password'})
      .to_return(status: 403)

      auth_token = api_different.request_login

      expect(login_request).not_to have_been_made
      expect(incorrect_request).to have_been_made.once
      expect(auth_token).to be_blank
    end

  end

  context 'sending requests' do

    it 'should successfully send a basic request' do
      basic_request = stub_request(:get, 'http://localhost:3030/')
      api.send_request('send basic get request', :get, host, port, '/', '')
      expect(basic_request).to have_been_made.once
    end

    it 'should fail on bad request' do
      endpoint_access = domain + '/does_not_exist'
      expect { api.send_request('will fail', :get, host, port, endpoint_access, '')
      }.to raise_error
    end
  end

  context 'check project access ' do
    it 'should succeed with valid credentials' do
      auth_token = 'auth_token_string'
      endpoint_access = domain + BawWorkers::Settings.endpoints.audio_recording_uploader
      body = {}
      access_request = stub_request(:get, "http://localhost:3030/projects/1/sites/1/audio_recordings/check_uploader/1").
          with(headers: {'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string"', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
          to_return(status: 204)

      expect(api.check_uploader_project_access(1, 1, 1, auth_token)).to be_truthy
      expect(access_request).to have_been_made.once
    end

    it 'should fail with invalid credentials' do
      auth_token = 'auth_token_string_wrong'
      endpoint_access = domain + BawWorkers::Settings.endpoints.audio_recording_uploader
      body = {}
      access_request = stub_request(:get, "http://localhost:3030/projects/1/sites/1/audio_recordings/check_uploader/1").
          with(headers: {'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string_wrong"', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
          to_return(status: 403)

      expect(api.check_uploader_project_access(1, 1, 1, auth_token)).to be_falsey
      expect(access_request).to have_been_made.once
    end

  end

  context 'update audio recording metadata' do
    it 'should succeed with valid credentials' do
      auth_token = 'auth_token_string'
      endpoint = domain + BawWorkers::Settings.endpoints.audio_recording_update_status
      body = {}
      access_request = stub_request(:put, "http://localhost:3030/audio_recordings/1").
          with(headers: {'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string"',
                         'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
          to_return(status: 204)

      expect(api.update_audio_recording_details(
                 'description',
                 'file',
                 1,
                 {},
                 auth_token)).to be_truthy
      expect(access_request).to have_been_made.once
    end

    it 'should fail with invalid credentials' do
      auth_token = 'auth_token_string_wrong'
      endpoint = domain + BawWorkers::Settings.endpoints.audio_recording_update_status
      body = {}
      access_request = stub_request(:put, 'http://localhost:3030/audio_recordings/1').
          with(headers: {'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string_wrong"',
                         'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
          to_return(status: 403)

      expect(api.update_audio_recording_details(
                 'description',
                 'file',
                 1,
                 {},
                 auth_token
             )).to be_falsey
      expect(access_request).to have_been_made.once
    end

  end
end