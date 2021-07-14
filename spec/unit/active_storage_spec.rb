# frozen_string_literal: true



describe 'Active storage' do
  it 'should have an active storage configuration' do
    expect(Rails.configuration.active_storage).to_not be_nil
  end

  it 'should be using disk' do
    expect(Rails.configuration.active_storage.service).to be(:local)
  end

  it 'should be using disk' do
    expect(ActiveStorage::Blob.service).to be_a_kind_of(ActiveStorage::Service::DiskService)
  end
end
