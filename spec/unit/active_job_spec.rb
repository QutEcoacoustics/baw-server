# frozen_string_literal: true

# A holdover from
#         # https://github.com/rails/rails/issues/37270
# When the configured test adapter was overridden by rails no matter what we did.
# Test is kept as a sanity check, but all the patch code has been removed.
describe 'Active Job' do
  include ActiveJob::TestHelper

  it 'is using the resque adapter by default' do
    expect(ActiveJob::Base.queue_adapter).to be_a(ActiveJob::QueueAdapters::ResqueAdapter)
  end

  it 'there is a alias to the current adapter' do
    expect(queue_adapter).to be_a(ActiveJob::QueueAdapters::ResqueAdapter)
  end
end
