# frozen_string_literal: true

require 'workers_helper'

describe BawWorkers::UploadService::Communicator do
  it 'can be instantiated' do
    upload_service = BawWorkers::UploadService::Communicator.new(
      config: Settings.upload_service,
      logger: BawWorkers::Config.logger_worker
    )

    expect(upload_service).to_not be_nil
    expect(upload_service.client).to be_a(SftpgoClient::ApiClient)
    expect(upload_service.client.connection).to be_a(Faraday::Connection)

    base_uri = URI("http://#{Settings.upload_service.host}:#{Settings.upload_service.port}/api/v1/")
    expect(upload_service.client.base_uri).to eq(base_uri)
    expect(upload_service.client.connection.url_prefix).to eq(base_uri)

    expect(upload_service.service_logger).to be_a(Logger)
    expect(upload_service.service_logger).to be(BawWorkers::Config.logger_worker)
  end

  it 'will use https in prod' do
    allow(BawApp).to receive(:dev_or_test?).and_return(false)
    upload_service = BawWorkers::UploadService::Communicator.new(
      config: Settings.upload_service,
      logger: BawWorkers::Config.logger_worker
    )

    base_uri = URI("https://#{Settings.upload_service.host}:#{Settings.upload_service.port}/api/v1/")
    expect(upload_service.client.base_uri).to eq(base_uri)
    expect(upload_service.client.connection.url_prefix).to eq(base_uri)
  end

  it 'SftpgoClient::ApiClient will not put up with your schemes' do
    expect {
      SftpgoClient::ApiClient.new(
        username: Settings.upload_service.username,
        password: Settings.upload_service.password,
        scheme: 'malarkey',
        host: Settings.upload_service.host,
        port: Settings.upload_service.port,
        logger: BawWorkers::Config.logger_worker
      )
    }.to raise_error(ArgumentError, 'Unsupported scheme `malarkey`')
  end

  it 'is defined on Baw::Workers::Config be default' do
    expect(BawWorkers::Config).to have_attributes(upload_communicator: be_a(BawWorkers::UploadService::Communicator))
  end

  it 'can return the admin interface link' do
    expect(BawWorkers::Config.upload_communicator.admin_url).to eq('http://upload:8080/')
  end

  it 'send basic auth on requests' do
    BawWorkers::Config.upload_communicator.server_version

    expected_basic_auth = Base64.strict_encode64("#{Settings.upload_service.username}:#{Settings.upload_service.password}").chomp

    request = a_request(:get, 'http://upload:8080/api/v1/version')
              .with(headers: {
                'Accept' => 'application/json',
                'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Authorization' => "Basic #{expected_basic_auth}",
                'Content-Type' => 'application/json',
                'User-Agent' => 'workbench-server/sftpgo-client'
              })

    expect(request).to have_been_made.once
  end

  it 'throws when asking for an invalid user' do
    expect {
      BawWorkers::Config.upload_communicator.get_user(123_456)
    }.to raise_error(
      an_instance_of(Faraday::ResourceNotFound)
      .and(having_attributes(response: a_hash_including({
        status: 404,
        headers: be_a(Hash),
        body: SftpgoClient::ApiResponse.new(
          error: 'Not found: sql: no rows in result set',
          message: ''
        )
      })))
    )
  end
end
