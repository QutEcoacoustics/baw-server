# frozen_string_literal: true

describe 'Active Job' do
  include ActiveJob::TestHelper

  # #resque_log_level :debug

  it 'is using the resque adapter by default' do
    logger.info('test!')
    logger.debug('test!')
    expect(ActiveJob::Base.queue_adapter).to be_a(ActiveJob::QueueAdapters::ResqueAdapter)
  end

  it 'there is a alias to the test adapter that can be used' do
    expect(queue_adapter_for_test).to be_a(ActiveJob::QueueAdapters::TestAdapter)
  end

  it 'there is a alias to the current adapter' do
    expect(queue_adapter).to be_a(ActiveJob::QueueAdapters::ResqueAdapter)
  end
end
