# frozen_string_literal: true

require 'workers_helper'

describe BawWorkers::UploadService::Communicator do
  it 'can be instantiated' do
    upload_service = BawWorkers::UploadService::Communicator.new(
      upload_service: Settings.upload_service,
      logger: BawWorkers::Config.logger_worker
    )

    expect(upload_service).to_not be_nil
    expect(upload_service.service).to be_a(SftpgoGeneratedClient::ApiClient)
    expect(upload_service.service_config).to be_a(SftpgoGeneratedClient::Configuration)

    host_port = "#{Settings.upload_service.host}:#{Settings.upload_service.port}"
    expect(upload_service.service_config.host).to eq(host_port)

    expect(upload_service.service_config.username).to eq(Settings.upload_service.username)
    expect(upload_service.service_config.password).to eq(Settings.upload_service.password)

    expect(upload_service.service_logger).to be_a(Logger)
    expect(upload_service.service_logger).to be(BawWorkers::Config.logger_worker)
    expect(upload_service.service.config).to be(upload_service.service_config)
  end

  it 'is defined on Baw::Workers::Config be default' do
    expect(BawWorkers::Config).to have_attributes(upload_communicator: be_a(BawWorkers::UploadService::Communicator))
  end

  it 'can return the admin interface link' do
    expect(BawWorkers::Config.upload_communicator.admin_url).to eq('http://upload:8080/')
  end
end
