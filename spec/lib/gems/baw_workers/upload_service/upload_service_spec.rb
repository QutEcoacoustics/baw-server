# frozen_string_literal: true

require_relative 'upload_service_steps'
require 'support/shared_test_helpers'

describe BawWorkers::UploadService::Communicator do
  include UploadServiceSteps
  include Dry::Monads[:result]
  include_context 'shared_test_helpers'

  it 'can be instantiated' do
    upload_service = BawWorkers::UploadService::Communicator.new(
      config: Settings.upload_service,
      logger: BawWorkers::Config.logger_worker
    )

    expect(upload_service).not_to be_nil
    expect(upload_service.client).to be_a(SftpgoClient::ApiClient)
    expect(upload_service.client.connection).to be_a(Faraday::Connection)

    base_uri = URI("http://#{Settings.upload_service.admin_host}:#{Settings.upload_service.port}/api/v2/")
    expect(upload_service.client.base_uri).to eq(base_uri)
    expect(upload_service.client.connection.url_prefix).to eq(base_uri)

    expect(upload_service.service_logger).to be_a(SemanticLogger::Logger)
    expect(upload_service.service_logger).to be(BawWorkers::Config.logger_worker)
  end

  it 'will use https in prod' do
    allow(BawApp).to receive(:http_scheme).and_return('https')
    upload_service = BawWorkers::UploadService::Communicator.new(
      config: Settings.upload_service,
      logger: BawWorkers::Config.logger_worker
    )

    base_uri = URI("https://#{Settings.upload_service.admin_host}:#{Settings.upload_service.port}/api/v2/")
    expect(upload_service.client.base_uri).to eq(base_uri)
    expect(upload_service.client.connection.url_prefix).to eq(base_uri)
  end

  it 'SftpgoClient::ApiClient will not put up with your schemes' do
    expect {
      SftpgoClient::ApiClient.new(
        username: Settings.upload_service.username,
        password: Settings.upload_service.password,
        scheme: 'malarkey',
        host: Settings.upload_service.admin_host,
        port: Settings.upload_service.port,
        logger: BawWorkers::Config.logger_worker
      )
    }.to raise_error(ArgumentError, 'Unsupported scheme `malarkey`')
  end

  it 'is defined on BawWorkers::Config be default' do
    expect(BawWorkers::Config).to have_attributes(upload_communicator: be_a(BawWorkers::UploadService::Communicator))
  end

  it 'can return the admin interface link' do
    expect(BawWorkers::Config.upload_communicator.admin_url).to eq("http://#{Settings.upload_service.admin_host}:8080/")
  end

  it 'send basic auth on requests' do
    upload_service = BawWorkers::UploadService::Communicator.new(
      config: Settings.upload_service,
      logger: BawWorkers::Config.logger_worker
    )
    upload_service.server_version

    auth_request = a_request(:get, "http://#{Settings.upload_service.admin_host}:8080/api/v2/token")
                   .with(headers: {
                     'Accept' => 'application/json',
                     'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                     'Authorization' => 'Basic YWRtaW46cGFzc3dvcmQ=',
                     'Content-Type' => 'application/json',
                     'User-Agent' => 'workbench-server/sftpgo-client'
                   })
    actual_request = a_request(:get, "http://#{Settings.upload_service.admin_host}:8080/api/v2/version")
                     .with(headers: {
                       'Accept' => 'application/json',
                       'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                       'Authorization' => /Bearer .*/,
                       'Content-Type' => 'application/json',
                       'User-Agent' => 'workbench-server/sftpgo-client'
                     })

    expect(auth_request).to have_been_made.once
    expect(actual_request).to have_been_made.once
  end

  it 'throws when asking for an invalid user' do
    error_object = nil
    expect {
      BawWorkers::Config.upload_communicator.get_user('hansolo')
    }.to raise_error(BawWorkers::UploadService::UploadServiceError) do |error|
      error_object = error
    end

    inner = error_object.cause

    expect(inner.response).to match(a_hash_including({
      status: 404,
      headers: an_instance_of(Hash),
      body: an_object_having_attributes(
        error: 'Not Found',
        message: ''
      )
    }))
  end

  stepwise 'getting service status' do
    before do
      clear_harvester_to_do
      expect_configured_service
    end

    step 'when we check ther serice status' do
      @service_status = BawWorkers::Config.upload_communicator.service_status
    end

    step 'then it should have good status' do
      expect(@service_status).to be_an_instance_of(::Dry::Monads::Success)
      expect(@service_status.value!).to be_an_instance_of(SftpgoClient::ServicesStatus)
      expect(@service_status.value!.data_provider[:error]).to be_blank
    end

    step 'if we make the serice unavailable' do
      stub_request(:get, "#{Settings.upload_service.admin_host}:8080/api/v2/status")
        .to_return(body: 'error message', status: 500)
    end

    step 'when we check ther serice status' do
      @service_status = BawWorkers::Config.upload_communicator.service_status
    end

    step 'then the status should be bad' do
      expect(@service_status).to be_failure
      expect(@service_status.failure.to_s).to match(/error message/)
    end
  end

  it 'can get version information' do
    version_info = BawWorkers::Config.upload_communicator.server_version
    expect(version_info).to be_success
    expect(version_info.value!).to match(a_hash_including({
      version: /\d+\.\d+\.\d+/
    }))
  end

  stepwise 'creating and deleting users' do
    before do
      expect_configured_service
    end

    let(:users_table) {
      [
        ['name', 'password'],
        ['abcd',  'password'],
        ['efgh',  'password'],
        ['ijkl',  'password']
      ]
    }

    step 'when we create users' do
      @users = users_table.map { |(username, password)|
        BawWorkers::Config.upload_communicator.create_upload_user(username:, password:)
      }
    end

    step 'then we can query for users' do
      @found_users = get_all_upload_users
    end

    step 'then we should find those same users' do
      expect(@found_users).to include(*@users)
    end

    step 'when we delete all users' do
      delete_all_upload_users
    end

    step 'then we expect 0 users' do
      @found_users = get_all_upload_users
      expect(@found_users).to have(0).items
    end
  end

  stepwise 'uploading a file' do
    before do
      clear_harvester_to_do
      expect_configured_service
      ensure_no_upload_users
    end

    step 'when i create a user harvester_123 with password abc' do
      create_upload_user('harvester_123', 'abc')
    end

    step 'then that user should expire in 7 days' do
      expect(@user.expiration_date).to be_within(60_000).of((Time.now + 7.days).to_i * 1000)
    end

    step 'and I can uplod a file' do
      @source = Fixtures.audio_file_mono
      upload_file(@connection, @source)
    end

    step 'then it should exist in the harvester directory' do
      #tmp/_harvester_to_do_path/harvest_1/test-audio-mono.ogg
      expected = Pathname(harvest_to_do_path) / @username / @source.basename
      expect(File).to exist(expected), expected
    end

    [
      # file, to, expected
      [:sqlite_fixture,            '/', './'],
      # testing uploading afiles to the same spot
      [:sqlite_fixture,            '/', './'],
      [:audio_file_amp_channels_1, '/nested/a/b/c/', './nested/a/b/c'],
      [:audio_file_wac_2,          '/sub/a/./../', './sub'],
      [:audio_file_wac_1,          '/../../../', './']
    ].each do |file, to, expected|
      step "I can upload #{file} to #{to} and it will end up at #{expected}" do
        send_path = Fixtures.send(file)
        upload_file(@connection, send_path, to:)

        expected_path = Pathname(harvest_to_do_path) / @username / expected / send_path.basename
        expect(File).to exist(expected_path)
      end
    end

    step 'and finally I can remotely delete the files those same files' do
      local_dir = Pathname(harvest_to_do_path) / @username
      remote_dir = '/'
      recursive_delete_remote_files(@connection, local_dir, remote_dir)
    end
  end

  stepwise 'testing user ableness' do
    before do
      clear_harvester_to_do
      expect_configured_service
      ensure_no_upload_users
    end

    step 'when i create a user' do
      create_upload_user('harvester_456', 'abc')
    end

    step 'the user should be enabled' do
      expect_ableness(enabled: true)
    end

    step 'when i disable that user' do
      set_upload_user_ableness(enabled: false)
    end

    step 'the user should be disabled' do
      expect_ableness(enabled: false)
    end

    step 'and they should not be able to upload files' do
      source = Fixtures.audio_file_mono
      upload_file(@connection, source, should_work: false)
      expect_empty_directories(Pathname(harvest_to_do_path) / @username)
    end

    step 'if I then enable the user' do
      set_upload_user_ableness(enabled: true)
    end

    step 'the user should be enabled' do
      expect_ableness(enabled: true)
    end

    step 'and I can upload a file' do
      @source = Fixtures.audio_file_mono
      upload_file(@connection, @source)
    end

    step 'then it should exist in the harvester directory' do
      #tmp/_harvester_to_do_path/harvest_1/test-audio-mono.ogg
      expected = Pathname(harvest_to_do_path) / @username / @source.basename
      expect(File).to exist(expected), expected
    end
  end
end
