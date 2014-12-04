require 'spec_helper'

describe BawWorkers::Harvest::SingleFile do
  include_context 'shared_test_helpers'

  let(:file_info) { BawWorkers::Config.file_info }

  let(:api_comm) { BawWorkers::Config.api_communicator}

  let(:gather_files) {
    BawWorkers::Harvest::GatherFiles.new(
        BawWorkers::Config.logger_worker,
        file_info,
        BawWorkers::Settings.available_formats.audio,
        BawWorkers::Settings.actions.harvest.config_file_name
    )
  }

  let(:single_file) {
    BawWorkers::Harvest::SingleFile.new(
        BawWorkers::Config.logger_worker,
        file_info,
        api_comm,
        BawWorkers::Config.original_audio_helper
    )
  }

  let(:to_do_dir) { BawWorkers::Settings.actions.harvest.to_do_path }

  let(:example_audio) { audio_file_mono }

  let(:folder_example) { File.expand_path File.join(File.dirname(__FILE__), 'folder_example.yml') }

  context 'entire process' do

    it 'should succeed with valid file and settings' do
      # set up audio file and folder config
      sub_folder = File.expand_path File.join(harvest_to_do_path, 'harvest_file_exists')
      FileUtils.mkpath(sub_folder)

      source_audio_file = File.expand_path File.join('.', 'spec', 'example_media', 'test-audio-mono.ogg')
      dest_audio_file = File.join(sub_folder, 'test_20141012_181455.ogg')

      source_harvest_folder_config = folder_example
      dest_harvest_folder_config = File.join(sub_folder, 'harvest.yml')

      FileUtils.copy(source_harvest_folder_config, dest_harvest_folder_config)
      FileUtils.copy(source_audio_file, dest_audio_file)

      # stub web requests
      email = 'address@example.com'
      user_name = 'example_user'
      password = 'password'
      auth_token = 'auth token this is'

      file_hash = 'SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891'
      recorded_date = '2014-10-12T18:14:55.000+10:00'
      uuid = 'fb4af424-04c1-4739-96e3-23f8dc719665'
      original_format = 'ogg'

      request_login_body = get_api_security_request(email, password)
      response_login_body =  get_api_security_response(user_name, auth_token)
      request_headers_base = {'Accept' => 'application/json', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}
      request_headers = request_headers_base.merge('Authorization' => "Token token=\"#{auth_token}\"")
      request_create_body = {
          uploader_id: 30,
          recorded_date: recorded_date,
          site_id: 20,
          duration_seconds: 70.0,
          sample_rate_hertz: 44100,
          channels: 1,
          bit_rate_bps: 239920,
          media_type: 'audio/ogg',
          data_length_bytes: 822281,
          file_hash: file_hash,
          original_file_name: 'test_20141012_181455.ogg'
      }
      response_create_body = {
          uploader_id: 30,
          recorded_date: '2014-10-12T08:14:55Z',
          site_id: 20,
          duration_seconds: 70.0,
          sample_rate_hertz: 44100,
          channels: 1,
          bit_rate_bps: 239920,
          media_type: 'audio/ogg',
          data_length_bytes: 822281,
          file_hash: file_hash,
          status: 'new',
          original_file_name: 'test_20141012_181455.ogg',

          created_at: "2014-10-13T05:21:13Z",
          creator_id: 1208,
          deleted_at: nil,
          deleter_id: nil,
          id: 177,
          notes: "note number 183",
          updated_at: "2014-10-13T05:21:13Z",
          updater_id: nil,
          uuid: uuid
      }
      request_update_status_body = {
          uuid: uuid,
          file_hash: file_hash,
          status: nil
      }

      possible_paths = audio_original.possible_paths(
          {
              uuid: uuid,
              datetime_with_offset: Time.zone.parse(recorded_date),
              original_format: original_format
          }
      )

      stub_login = stub_request(:post, "http://localhost:3030/security")
      .with(body: request_login_body.to_json, headers: request_headers_base)
      .to_return(status: 200, body: response_login_body.to_json)

      stub_uploader_check = stub_request(:get, "http://localhost:3030/projects/10/sites/20/audio_recordings/check_uploader/30")
      .with(headers: request_headers)
      .to_return(status: 204)

      stub_create = stub_request(:post, "http://localhost:3030/projects/10/sites/20/audio_recordings")
      .with(body: request_create_body.to_json, headers: request_headers)
      .to_return(status: 201, body: response_create_body.to_json)

      stub_uploading_status = stub_request(:put, "http://localhost:3030/audio_recordings/177/update_status")
      .with(body: request_update_status_body.merge(status: 'uploading'), headers: request_headers)
      .to_return(status: 200)

      stub_ready_status = stub_request(:put, "http://localhost:3030/audio_recordings/177/update_status")
      .with(body: request_update_status_body.merge(status: 'ready'), headers: request_headers)
      .to_return(status: 200)

      # execute - process a single file
      file_info_hash = gather_files.run(dest_audio_file)
      single_file.run(file_info_hash[0], false)

      # verify - requests made in the correct order
      stub_login.should have_been_made.once
      stub_uploader_check.should have_been_made.once
      stub_create.should have_been_made.once
      stub_uploading_status.should have_been_made.once
      stub_ready_status.should have_been_made.once

      # ensure file is moved to correct location
      expect(File.exists?(possible_paths[1])).to be_truthy

      # ensure source file is renamed to *.completed
      expect(File.exists?(dest_audio_file)).to be_falsey
      expect(File.exists?(dest_audio_file+'.completed')).to be_truthy
    end

  end

end