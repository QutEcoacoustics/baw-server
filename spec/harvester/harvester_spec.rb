require 'spec_helper'
require 'pathname'
require 'modules/exceptions'
require 'external/harvester/harvester'

include Warden::Test::Helpers
Warden.test_mode!

describe Harvester do

  let(:harvester_file) { File.join(Rails.root, 'lib', 'external', ' harvester', 'harvester.rb') }
  let(:this_file) { __FILE__ }
  let(:this_dir) { File.dirname(this_file) }

  let(:source_audio_file) { File.join(Rails.root, 'spec', 'media_tools', 'test-audio-mono.ogg') }
  let(:source_harvest_file) { File.join(this_dir, 'harvest.yml') }
  let(:source_config_file) { File.join(Rails.root, 'lib', 'external', 'harvester', 'harvester_default.yml') }

  let(:dir_to_do) { File.join(Rails.root, 'tmp', '_harvester_to_do') }
  let(:dir_to_do_subdir) { File.join(dir_to_do, 'testing') }
  let(:dir_complete) { File.join(Rails.root, 'tmp', '_harvester_completed') }
  let(:dir_original_audio) { File.join(Rails.root, 'tmp', '_original_audio') }

  let(:target_audio_file) { File.join(dir_to_do_subdir, File.basename(source_audio_file)) }
  let(:target_harvest_file) { File.join(dir_to_do_subdir, File.basename(source_harvest_file)) }
  let(:target_config_file) { File.join(dir_to_do, 'harvester_settings.yml') }

  let(:harvester) { Harvester::Harvester.new(target_config_file, dir_to_do_subdir) }

  before(:each) do
    # create to_do directory, put harvest.yml and audio file into it
    FileUtils.mkpath(dir_to_do_subdir)
    FileUtils.cp(source_audio_file, target_audio_file)
    FileUtils.cp(source_harvest_file, target_harvest_file)
    FileUtils.cp(source_config_file, target_config_file)

    # create completed directory
    FileUtils.mkpath(dir_complete)
  end

  after(:each) do
    # remove to_do directory
    FileUtils.rm_rf(dir_to_do)

    # remove completed directory
    FileUtils.rm_rf(dir_complete)

    # remove original audio directory
    FileUtils.rm_rf(dir_original_audio)
  end


  context 'creating a new harvester' do

    it 'throws an error when given no config file' do
      expect {
        Harvester::Harvester.new('', '')
      }.to raise_error(Exceptions::HarvesterConfigFileNotFound, /Configuration file not found./)
    end

    it 'throws an error when given invalid path to config file' do
      expect {
        Harvester::Harvester.new('somewhere', '')
      }.to raise_error(Exceptions::HarvesterConfigFileNotFound, /Configuration file not found./)
    end

    it 'throws an error when given empty dir to config file' do
      expect {
        Harvester::Harvester.new(target_config_file, '')
      }.to raise_error(Exceptions::HarvesterConfigurationError, /Directory to process not found./)
    end

    it 'throws an error when given invalid dir to config file' do
      expect {
        Harvester::Harvester.new(target_config_file, 'somewhere')
      }.to raise_error(Exceptions::HarvesterConfigurationError, /Directory to process not found./)
    end

  end

  context 'running the harvester' do

    before(:each) do
      @permission = FactoryGirl.create(:read_permission)
      @harvester = FactoryGirl.create(:harvester)
      login_as @harvester, scope: :harvester
    end

    it 'works as intended' do

      auth_token = SecureRandom.urlsafe_base64(nil, false)

      # 1. log in
      stub_request(:post, 'http://localhost:3030/security/sign_in')
      .with(body: '{"email":"address@example.com","password":"password"}')
      .to_return(body: '{"success":true,"auth_token":"'+auth_token+'","email":"address@example.com"}')

      # 2. Check uploader id
      stub_request(:get, 'http://localhost:3030/projects/1/sites/1/audio_recordings/check_uploader')
      .with(body: '{"uploader_id":1}')
      .to_return(body: '', status: 204)

      # 3. create audio recording on server
      stub_request(:post, 'localhost:3030/projects/1/sites/1/audio_recordings')
      .to_return(status: 201, body: {
          bit_rate_bps: 93974,
          channels: 1,
          created_at: "2014-02-07T18:49:54+10:00",
          creator_id: 1,
          data_length_bytes: 822281,
          deleted_at: nil,
          deleter_id: nil,
          duration_seconds: 70.0,
          file_hash: "SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891",
          id: 240042,
          media_type: "audio/ogg",
          notes: nil,
          original_file_name: "test-audio-mono.ogg",
          recorded_date: "2014-02-07T17:50:03+10:00",
          sample_rate_hertz: 44100,
          site_id: 1001,
          status: "new",
          updated_at: "2014-02-07T18:49:54+10:00",
          updater_id: 1,
          uploader_id: 1,
          uuid: "d71c603f-2f65-4f3f-8a18-67d62f764001"
      }.to_json)

      # 4. record moving the original audio file
      stub_request(:put, 'localhost:3030/audio_recordings/240042/update_status')
      .with(body: '{"auth_token":"'+auth_token+'","audio_recording":{"file_hash":"SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891","uuid":"d71c603f-2f65-4f3f-8a18-67d62f764001"}}')
      .to_return(status: 204)

      harvester.start_harvesting

    end

  end

end