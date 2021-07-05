# frozen_string_literal: true

describe BawWorkers::ActiveJob::Identity::Generators do
  before do
    # get a copy of the class that is unmodified from the rails initializers
    original = ::ActiveJob::Base.const_get(:ACTIVE_JOB_BASE_BACKUP)
    stub_const('::ActiveJob::Base', original.clone)
    fake_job = Class.new(::ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity))
    stub_const('FakeJob', fake_job)
  end

  let(:job) { FakeJob.new('arguments', 123, { complex: :hash, abc: [4, 1, 0] }) }

  it 'can generate a uuid' do
    result = BawWorkers::ActiveJob::Identity::Generators.generate_uuid(job)
    expect(result).to match /FakeJob:[-a-f0-9]{36}/
  end

  it 'can generate a deterministic hash' do
    result = BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(job)
    expect(result).to eq('FakeJob:c1dc6d8b3863caabc2bd32d342f01b83')
  end

  it 'can generate a deterministic hash with a different order of args' do
    job_with_different_order_args = FakeJob.new(123, 'arguments', { abc: [0, 1, 4], complex: :hash })
    result = BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(job_with_different_order_args)
    expect(result).to eq('FakeJob:c1dc6d8b3863caabc2bd32d342f01b83')
  end

  it 'can template a hash string into a key' do
    result = BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(job, { a: 1, b: 'hello' })
    expect(result).to eq('FakeJob:a=1:b=hello')
  end

  it 'will replace non alpha-numeric characters complex values in generate_keyed_id' do
    result = BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(job, { a: 1, b: { some: 'complex_hash' } })
    expect(result).to eq('FakeJob:a=1:b=-some-complex_hash-')
  end

  it 'will fail if it generates a key that is too long in generate_keyed_id' do
    expect {
      BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(job, { a: 'banana' * 1000 })
    }.to raise_error ArgumentError
  end
end
