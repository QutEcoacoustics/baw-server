require 'spec_helper'

describe BawWorkers::Harvest::SingleFile do
  include_context 'media_file'

  let(:config_file_name) { 'harvest.yml' }

  let(:file_info) { BawWorkers::FileInfo.new(BawWorkers::Settings.logger, BawWorkers::Settings.audio_helper) }

  let(:api_comm) {
    BawWorkers::ApiCommunicator.new(
        BawWorkers::Settings.logger,
        BawWorkers::Settings.api,
        BawWorkers::Settings.endpoints)
  }

  let(:gather_files) {
    BawWorkers::Harvest::GatherFiles.new(
        BawWorkers::Settings.logger,
        file_info,
        Settings.available_formats.audio,
        config_file_name
    )
  }

  let(:single_file) {
    BawWorkers::Harvest::SingleFile.new(
        BawWorkers::Settings.logger,
        file_info,
        api_comm
    )
  }

  let(:to_do_dir) { BawWorkers::Settings.paths.harvester_to_do }

  let(:example_audio) { audio_file_mono }

  let(:folder_example) { File.expand_path File.join(File.dirname(__FILE__), 'folder_example.yml') }

  context 'entire process' do

    it 'should succeed with valid file and settings' do
      # set up audio file and folder config
      sub_folder = File.expand_path File.join('..', 'tmp', '_harvester_to_do', 'harvest_file_exists')
      FileUtils.mkpath(sub_folder)

      source_audio_file = File.expand_path File.join('.', 'spec', 'example_media', 'test-audio-mono.ogg')
      dest_audio_file = File.join(sub_folder, 'test_20141012_181455.ogg')

      source_harvest_folder_config = folder_example
      dest_harvest_folder_config = File.join(sub_folder, 'harvest.yml')

      FileUtils.copy(source_harvest_folder_config, dest_harvest_folder_config)
      FileUtils.copy(source_audio_file, dest_audio_file)

      # stub web requests
      user = 'address@example.com'
      password = 'password'
      auth_token = 'auth token this is'

      stub_login = stub_request(:post, "http://localhost:3030/security/sign_in")
      .with(
          body: "{\"email\":\"#{user}\",\"password\":\"#{password}\"}",
          headers: {'Accept' => 'application/json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'})
      .to_return(
          status: 200,
          body: "{\"success\":\"true\",\"auth_token\":\"#{auth_token}\",\"email\":\"#{user}\"}")

      stub_uploader_check = stub_request(:get, "http://localhost:3030/projects/10/sites/20/audio_recordings/check_uploader/30")
      .with(
          headers: {'Accept' => 'application/json', 'Authorization' => "Token token=\"#{auth_token}\"", 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'})
      .to_return(
          status: 204)


      # process a single file
      file_info_hash = gather_files.process_file(dest_audio_file)
      single_file.run(file_info_hash)
    end

  end

end