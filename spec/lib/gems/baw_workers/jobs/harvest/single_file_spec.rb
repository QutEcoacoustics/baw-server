# frozen_string_literal: true

describe BawWorkers::Jobs::Harvest::SingleFile do
  require 'support/shared_test_helpers'

  include_context 'shared_test_helpers'

  let(:file_info) { BawWorkers::Config.file_info }

  let(:api_comm) { BawWorkers::Config.api_communicator }

  let(:gather_files) {
    BawWorkers::Jobs::Harvest::GatherFiles.new(
      BawWorkers::Config.logger_worker,
      file_info,
      Settings.available_formats.audio + Settings.available_formats.audio_decode_only,
      Settings.actions.harvest.config_file_name,
      to_do_root: Pathname(Settings.actions.harvest.to_do_path).realpath
    )
  }

  let(:single_file) {
    BawWorkers::Jobs::Harvest::SingleFile.new(
      BawWorkers::Config.logger_worker,
      file_info,
      api_comm,
      BawWorkers::Config.original_audio_helper
    )
  }

  let(:example_audio) { audio_file_mono }

  let(:folder_example) { File.expand_path File.join(File.dirname(__FILE__), 'folder_example.yml') }

  # TODO: tests need to be rewritten for new harvest implementation
  xcontext 'entire process' do
    it 'succeeds with valid ogg file and settings' do
      # set up audio file and folder config
      sub_folder = File.expand_path File.join(harvest_to_do_path, 'harvest_file_exists')
      FileUtils.mkpath(sub_folder)

      source_audio_file = audio_file_mono
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
      response_login_body = get_api_security_response(user_name, auth_token)
      request_headers_base = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
                               'User-Agent' => 'Ruby' }
      request_headers = request_headers_base.merge('Authorization' => "Token token=\"#{auth_token}\"")
      request_create_body = {
        uploader_id: 30,
        recorded_date:,
        site_id: 20,
        duration_seconds: 70.0,
        sample_rate_hertz: 44_100,
        channels: 1,
        bit_rate_bps: 239_920,
        media_type: 'audio/ogg',
        data_length_bytes: 822_281,
        file_hash:,
        original_file_name: 'test_20141012_181455.ogg',
        notes: {
          relative_path: 'test_20141012_181455.ogg',
          sensor_type: 'SM2',
          information: [
            'stripped left channel due to bad mic',
            'appears to have electronic interference from solar panel'
          ]
        }
      }
      response_create_body = {
        meta: {
          status: 201,
          message: 'Created'
        },
        data: {
          recorded_date: '2014-10-12T08:14:55Z',
          site_id: 20,
          duration_seconds: 70.0,
          sample_rate_hertz: 44_100,
          channels: 1,
          bit_rate_bps: 239_920,
          media_type: 'audio/ogg',
          data_length_bytes: 822_281,
          file_hash:,
          status: 'new',
          original_file_name: 'test_20141012_181455.ogg',

          created_at: '2014-10-13T05:21:13Z',
          id: 177,
          notes: 'note number 183',
          updated_at: '2014-10-13T05:21:13Z',
          uuid:
        }
      }

      request_update_status_body = {
        uuid:,
        file_hash:,
        status: nil
      }

      possible_paths = audio_original.possible_paths(
        uuid:,
        datetime_with_offset: Time.zone.parse(recorded_date),
        original_format:
      )

      stub_login = stub_request(:post, "#{default_uri}/security")
                   .with(body: request_login_body.to_json, headers: request_headers_base)
                   .to_return(status: 200, body: response_login_body.to_json)

      stub_uploader_check = stub_request(:get, "#{default_uri}/projects/10/sites/20/audio_recordings/check_uploader/30")
                            .with(headers: request_headers)
                            .to_return(status: 204)

      stub_create = stub_request(:post, "#{default_uri}/projects/10/sites/20/audio_recordings")
                    .with(body: request_create_body.to_json, headers: request_headers)
                    .to_return(status: 201, body: response_create_body.to_json)

      stub_uploading_status = stub_request(:put, "#{default_uri}/audio_recordings/177/update_status")
                              .with(body: request_update_status_body.merge(status: 'uploading'), headers: request_headers)
                              .to_return(status: 200)

      stub_ready_status = stub_request(:put, "#{default_uri}/audio_recordings/177/update_status")
                          .with(body: request_update_status_body.merge(status: 'ready'), headers: request_headers)
                          .to_return(status: 200)

      # execute - process a single file
      file_info_hash = gather_files.run(dest_audio_file)
      single_file.run(file_info_hash[0], true)

      # verify - requests made in the correct order
      stub_login.should have_been_made.once
      stub_uploader_check.should have_been_made.once
      stub_create.should have_been_made.once
      stub_uploading_status.should have_been_made.once
      stub_ready_status.should have_been_made.once

      # ensure file is moved to correct location
      expect(File).to exist(possible_paths[1])

      # ensure source file is renamed to *.completed
      expect(File).not_to exist(dest_audio_file)
      expect(File).to exist("#{dest_audio_file}.completed")

      # clean up
      FileUtils.rm_rf(sub_folder)
    end

    it 'succeeds with valid wac file and settings' do
      # set up audio file and folder config
      sub_folder = File.expand_path File.join(harvest_to_do_path, 'harvest_file_exists')
      FileUtils.mkpath(sub_folder)

      source_audio_file = audio_file_wac
      dest_audio_file = File.join(sub_folder, 'test_20141012_181455.wac')

      source_harvest_folder_config = folder_example
      dest_harvest_folder_config = File.join(sub_folder, 'harvest.yml')

      FileUtils.copy(source_harvest_folder_config, dest_harvest_folder_config)
      FileUtils.copy(source_audio_file, dest_audio_file)

      # stub web requests
      email = 'address@example.com'
      user_name = 'example_user'
      password = 'password'
      auth_token = 'auth token this is'

      file_hash = 'SHA256::c6d561c91664a92a1598bda3b79734d5ee29266ad0411ffaea1188f29d5b6439'
      recorded_date = '2014-10-12T18:14:55.000+10:00'
      uuid = 'fb4af424-04c1-4739-96e3-23f8dc719665'
      original_format = 'wac'

      request_login_body = get_api_security_request(email, password)
      response_login_body = get_api_security_response(user_name, auth_token)
      request_headers_base = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
                               'User-Agent' => 'Ruby' }
      request_headers = request_headers_base.merge('Authorization' => "Token token=\"#{auth_token}\"")
      request_create_body = {
        uploader_id: 30,
        recorded_date:,
        site_id: 20,
        duration_seconds: 6.577,
        sample_rate_hertz: 22_050,
        channels: 2,
        bit_rate_bps: 16,
        media_type: 'audio/x-waac',
        data_length_bytes: 394_644,
        file_hash:,
        original_file_name: 'test_20141012_181455.wac',
        notes: {
          relative_path: 'test_20141012_181455.wac',
          sensor_type: 'SM2',
          information: [
            'stripped left channel due to bad mic',
            'appears to have electronic interference from solar panel'
          ]
        }
      }
      response_create_body = {
        meta: {
          status: 201,
          message: 'Created'
        },
        data: {
          recorded_date: '2014-10-12T08:14:55Z',
          site_id: 20,
          duration_seconds: 6.577,
          sample_rate_hertz: 22_050,
          channels: 2,
          bit_rate_bps: 16,
          media_type: 'audio/x-waac',
          data_length_bytes: 394_644,
          file_hash:,
          status: 'new',
          original_file_name: 'test_20141012_181455.wac',

          created_at: '2014-10-13T05:21:13Z',
          id: 177,
          notes: 'note number 183',
          updated_at: '2014-10-13T05:21:13Z',
          uuid:
        }
      }

      request_update_status_body = {
        uuid:,
        file_hash:,
        status: nil
      }

      possible_paths = audio_original.possible_paths(
        uuid:,
        datetime_with_offset: Time.zone.parse(recorded_date),
        original_format:
      )

      stub_login = stub_request(:post, "#{default_uri}/security")
                   .with(body: request_login_body.to_json, headers: request_headers_base)
                   .to_return(status: 200, body: response_login_body.to_json)

      stub_uploader_check = stub_request(:get, "#{default_uri}/projects/10/sites/20/audio_recordings/check_uploader/30")
                            .with(headers: request_headers)
                            .to_return(status: 204)

      stub_create = stub_request(:post, "#{default_uri}/projects/10/sites/20/audio_recordings")
                    .with(body: request_create_body.to_json, headers: request_headers)
                    .to_return(status: 201, body: response_create_body.to_json)

      stub_uploading_status = stub_request(:put, "#{default_uri}/audio_recordings/177/update_status")
                              .with(body: request_update_status_body.merge(status: 'uploading'), headers: request_headers)
                              .to_return(status: 200)

      stub_ready_status = stub_request(:put, "#{default_uri}/audio_recordings/177/update_status")
                          .with(body: request_update_status_body.merge(status: 'ready'), headers: request_headers)
                          .to_return(status: 200)

      # execute - process a single file
      file_info_hash = gather_files.run(dest_audio_file)
      single_file.run(file_info_hash[0], true)

      # verify - requests made in the correct order
      stub_login.should have_been_made.once
      stub_uploader_check.should have_been_made.once
      stub_create.should have_been_made.once
      stub_uploading_status.should have_been_made.once
      stub_ready_status.should have_been_made.once

      # ensure file is moved to correct location
      expect(File).to exist(possible_paths[1])

      # ensure source file is renamed to *.completed
      expect(File).not_to exist(dest_audio_file)
      expect(File).to exist("#{dest_audio_file}.completed")

      # clean up
      FileUtils.rm_rf(sub_folder)
    end

    it 'renames audio file with short duration' do
      clear_original_audio

      # set up audio file and folder config
      sub_folder = File.expand_path File.join(harvest_to_do_path, 'harvest_file_exists')
      FileUtils.mkpath(sub_folder)

      source_audio_file = Fixtures.audio_file_mono29
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

      file_hash = 'SHA256::2bae85dae2f47fba00770c6163949f33cb905637fdcc5d1da6e0af9ae637af45'
      recorded_date = '2014-10-12T18:14:55.000+10:00'
      uuid = 'fb4af424-04c1-4739-96e3-23f8dc719665'
      original_format = 'ogg'

      request_login_body = get_api_security_request(email, password)
      response_login_body = get_api_security_response(user_name, auth_token)
      request_headers_base = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
                               'User-Agent' => 'Ruby' }
      request_headers = request_headers_base.merge('Authorization' => "Token token=\"#{auth_token}\"")
      request_create_body = {
        uploader_id: 30,
        recorded_date:,
        site_id: 20,
        duration_seconds: 29.0,
        sample_rate_hertz: 44_100,
        channels: 1,
        bit_rate_bps: 160_000,
        media_type: 'audio/ogg',
        data_length_bytes: 296_756,
        file_hash:,
        original_file_name: 'test_20141012_181455.ogg',
        notes: {
          relative_path: 'test_20141012_181455.ogg',
          sensor_type: 'SM2',
          information: [
            'stripped left channel due to bad mic',
            'appears to have electronic interference from solar panel'
          ]
        }
      }
      response_create_body = {
        meta: {
          status: 422,
          message: 'Unprocessable Entity',
          error: {
            details: 'Record could not be saved',
            info: {
              duration_seconds:
                    ['must be greater than or equal to 10']
            }
          }
        },
        data: nil
      }

      possible_paths = audio_original.possible_paths(
        uuid:,
        datetime_with_offset: Time.zone.parse(recorded_date),
        original_format:
      )

      stub_login = stub_request(:post, "#{default_uri}/security")
                   .with(body: request_login_body.to_json, headers: request_headers_base)
                   .to_return(status: 200, body: response_login_body.to_json)

      stub_uploader_check = stub_request(:get, "#{default_uri}/projects/10/sites/20/audio_recordings/check_uploader/30")
                            .with(headers: request_headers)
                            .to_return(status: 204)

      stub_create = stub_request(:post, "#{default_uri}/projects/10/sites/20/audio_recordings")
                    .with(body: request_create_body.to_json, headers: request_headers)
                    .to_return(status: 422, body: response_create_body.to_json)

      # execute - process a single file
      file_info_hash = gather_files.run(dest_audio_file)
      expect {
        single_file.run(file_info_hash[0], true)
      }.to raise_error(
        BawWorkers::Exceptions::HarvesterEndpointError,
        /test_20141012_181455.ogg failed: Code 422, Message: , Body: \{"meta":\{"status":422,"message":"Unprocessable Entity","error":\{"details":"Record could not be saved","info":\{"duration_seconds":\["must be greater than or equal to 10"\]\}\}\},"data":null\}, File renamed to/
      )

      # verify - requests made in the correct order
      stub_login.should have_been_made.once
      stub_uploader_check.should have_been_made.once
      stub_create.should have_been_made.once

      # ensure file was not moved to new location
      expect(File).not_to exist(possible_paths[1])

      # ensure source file is renamed to *.error_duration
      expect(File).not_to exist(dest_audio_file)
      expect(File).to exist("#{dest_audio_file}.error_duration")

      # clean up
      FileUtils.rm_rf(sub_folder)
    end

    it 'renames audio file with no content' do
      clear_original_audio

      # set up audio file and folder config
      sub_folder = File.expand_path File.join(harvest_to_do_path, 'harvest_file_exists')
      FileUtils.mkpath(sub_folder)

      dest_audio_file = File.join(sub_folder, 'test_20141012_181455.ogg')

      source_harvest_folder_config = folder_example
      dest_harvest_folder_config = File.join(sub_folder, 'harvest.yml')

      FileUtils.copy(source_harvest_folder_config, dest_harvest_folder_config)
      FileUtils.touch(dest_audio_file)

      recorded_date = '2014-10-12T18:14:55.000+10:00'
      uuid = 'fb4af424-04c1-4739-96e3-23f8dc719665'
      original_format = 'ogg'

      possible_paths = audio_original.possible_paths(
        uuid:,
        datetime_with_offset: Time.zone.parse(recorded_date),
        original_format:
      )

      # execute - process a single file
      file_info_hash = gather_files.run(dest_audio_file)
      expect {
        single_file.run(file_info_hash[0], true)
      }.to raise_error(BawAudioTools::Exceptions::FileEmptyError,
        /File has no content \(length of 0 bytes\) renamed to/)

      # ensure file was not moved to new location
      expect(File).not_to exist(possible_paths[1])

      # ensure source file is renamed to *.error_empty
      expect(File).not_to exist(dest_audio_file)
      expect(File).to exist("#{dest_audio_file}.error_empty")

      # clean up
      FileUtils.rm_rf(sub_folder)
    end
  end
end
