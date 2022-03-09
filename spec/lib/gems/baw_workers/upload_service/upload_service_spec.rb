# frozen_string_literal: true

describe BawWorkers::UploadService::Communicator do
  it 'can be instantiated' do
    upload_service = BawWorkers::UploadService::Communicator.new(
      config: Settings.upload_service,
      logger: BawWorkers::Config.logger_worker
    )

    expect(upload_service).not_to be_nil
    expect(upload_service.client).to be_a(SftpgoClient::ApiClient)
    expect(upload_service.client.connection).to be_a(Faraday::Connection)

    base_uri = URI("http://#{Settings.upload_service.host}:#{Settings.upload_service.port}/api/v2/")
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

    base_uri = URI("https://#{Settings.upload_service.host}:#{Settings.upload_service.port}/api/v2/")
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

  it 'is defined on BawWorkers::Config be default' do
    expect(BawWorkers::Config).to have_attributes(upload_communicator: be_a(BawWorkers::UploadService::Communicator))
  end

  it 'can return the admin interface link' do
    expect(BawWorkers::Config.upload_communicator.admin_url).to eq("http://#{Settings.upload_service.host}:8080/")
  end

  it 'send basic auth on requests' do
    upload_service = BawWorkers::UploadService::Communicator.new(
      config: Settings.upload_service,
      logger: BawWorkers::Config.logger_worker
    )
    upload_service.server_version

    auth_request = a_request(:get, "http://#{Settings.upload_service.host}:8080/api/v2/token")
                   .with(headers: {
                     'Accept' => 'application/json',
                     'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                     'Authorization' => 'Basic YWRtaW46cGFzc3dvcmQ=',
                     'Content-Type' => 'application/json',
                     'User-Agent' => 'workbench-server/sftpgo-client'
                   })
    actual_request = a_request(:get, "http://#{Settings.upload_service.host}:8080/api/v2/version")
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
    }.to raise_error(Faraday::ResourceNotFound) do |error|
      error_object = error
    end

    expect(error_object.response).to match(a_hash_including({
      status: 404,
      headers: an_instance_of(Hash),
      body: an_object_having_attributes(
        error: 'Not Found',
        message: ''
      )
    }))
  end
end
