require 'spec_helper'
require 'pathname'
require 'modules/exceptions'
require 'external/harvester/harvester'

describe Harvester do

  let(:dir_to_do) { File.join(File.dirname(__FILE__), 'to_do') }
  let(:dir_to_do_subdir) { File.join(dir_to_do, 'testing') }
  let(:dir_complete) { File.join(File.dirname(__FILE__), 'complete') }

  let(:source_audio_file) { File.join(File.dirname(__FILE__), '..', 'media_tools', 'test-audio-mono.ogg') }
  let(:target_audio_file) { File.join(dir_to_do_subdir, File.basename(source_audio_file)) }

  let(:source_harvest_file) { File.join(File.dirname(__FILE__), 'harvest.yml') }
  let(:target_harvest_file) { File.join(dir_to_do_subdir, File.basename(source_harvest_file)) }

  let(:source_config_file) { File.join(File.dirname(__FILE__), '..', '..', 'lib', 'external', 'harvester', 'harvester_default.yml') }
  let(:target_config_file) { File.join(dir_to_do, 'harvester_settings.yml') }

  let(:harvester) { Harvester::Harvester.new(target_config_file, dir_to_do) }

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
    #FileUtils.rm_rf(dir_to_do)

    # remove completed directory
    #FileUtils.rm_rf(dir_complete)
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

    it 'works as intended' do
      # 1. log in
      stub_request(:post, 'http://localhost:3030/security/sign_in')
      .with(body: '{"email":"address@example.com","password":"password"}')
      .to_return(body: '{"success":true,"auth_token":"'+SecureRandom.urlsafe_base64(nil, false)+'","email":"address@example.com"}')

      # 2. Check uploader id
      stub_request(:get, 'http://localhost:3030/projects/1/sites/1/audio_recordings/check_uploader')
      .with(body: '{"uploader_id":1}')
      .to_return(body: '', status: 204)

      harvester.start_harvesting

    end

  end

end