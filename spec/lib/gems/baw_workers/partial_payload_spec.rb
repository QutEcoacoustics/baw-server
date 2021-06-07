# frozen_string_literal: true



# noinspection RubyStringKeysInHashInspection
describe BawWorkers::RedisCommunicator do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  let(:redis) { BawWorkers::Config.redis_communicator }

  #let(:fake_redis) { Redis.new }

  it 'adds a key to redis when a partial payload is created' do
    result = BawWorkers::PartialPayload.create({ a: 1, b: 2, c: 3 }, 'analysis_job:123')

    expect(redis.exists('partial_payload:analysis_job:123')).to eq(true)

    expect(result.key?(:payload_base))
    expect(result[:payload_base]).to eq('baw-workers:partial_payload:analysis_job:123')
  end

  it 'can create or validate and existing base payload' do
    # important: after the first create, the last 4 will be validation, this `create` should
    # have only been called once.
    expect(BawWorkers::PartialPayload).to receive(:create).at_most(:once).and_call_original

    5.times do
      result = BawWorkers::PartialPayload.create_or_validate({ a: 1, b: 2, c: 3 }, 'analysis_job:123')

      expect(redis.exists('partial_payload:analysis_job:123')).to eq(true)

      expect(result.key?(:payload_base))
      expect(result[:payload_base]).to eq('baw-workers:partial_payload:analysis_job:123')
    end
  end

  it 'can create or validate and will fail if existing payload does not match' do
    result = BawWorkers::PartialPayload.create_or_validate({ a: 1, b: 2, c: 3 }, 'analysis_job:123')

    expect {
      result = BawWorkers::PartialPayload.create_or_validate({ a: 1, b: 2, c: 4 }, 'analysis_job:123')
    }.to raise_error(BawWorkers::InconsistentBasePayloadError)
  end

  it 'can remove payloads from redis' do
    BawWorkers::PartialPayload.create({ a: 1, b: 2, c: 3 }, 'analysis_job:123')

    expect(redis.exists('partial_payload:analysis_job:123')).to eq(true)

    BawWorkers::PartialPayload.delete('analysis_job:123')

    expect(redis.exists('partial_payload:analysis_job:123')).to eq(false)
  end

  it 'can resolve a payload' do
    # store base payload
    BawWorkers::PartialPayload.create({ a: 1, b: 2, c: 3 }, 'analysis_job:123')

    # 'dequeue' payload with reference to base payload
    # noinspection RubyStringKeysInHashInspection
    payload = { 'd' => 4, 'e' => 5, 'f' => 6, 'payload_base' => 'baw-workers:partial_payload:analysis_job:123' }

    resolved_payload = BawWorkers::PartialPayload.resolve(payload)

    expect(resolved_payload).to eq({ a: 1, b: 2, c: 3, d: 4, e: 5, f: 6 }.stringify_keys)
  end

  it 'will do nothing if no payload key is found' do
    # store base payload
    BawWorkers::PartialPayload.create({ a: 1, b: 2, c: 3 }, 'analysis_job:123')

    # 'dequeue' payload with reference to base payload
    payload = { d: 4, e: 5, f: 6 }.stringify_keys

    resolved_payload = BawWorkers::PartialPayload.resolve(payload)

    expect(resolved_payload).to eq({ d: 4, e: 5, f: 6 }.stringify_keys)
    # it should be the same instance!
    expect(resolved_payload).to equal(payload)
  end

  it 'can recursively resolve payloads' do
    result = {}
    (1..10).each do |index|
      # store each base payload - with the previous key
      result = BawWorkers::PartialPayload.create({ 'value_' + index.to_s => index }.merge(result), "analysis_job:#{index}")
    end

    # 'dequeue' payload with reference to base payload
    payload = { 'final' => 'concrete', payload_base: 'baw-workers:partial_payload:analysis_job:10' }

    resolved_payload = BawWorkers::PartialPayload.resolve(payload)

    # noinspection RubyStringKeysInHashInspection
    expect(resolved_payload).to eq('value_1' => 1, 'value_2' => 2, 'value_3' => 3, 'value_4' => 4,
                                   'value_5' => 5, 'value_6' => 6, 'value_7' => 7, 'value_8' => 8,
                                   'value_9' => 9, 'value_10' => 10, 'final' => 'concrete')
  end

  it 'can recursively delete partial payloads' do
    result = {}
    items = (1..10)

    items.each do |index|
      # store each base payload - with the previous key
      result = BawWorkers::PartialPayload.create({ 'value_' + index.to_s => index }.merge(result), "analysis_job:#{index}")
    end

    # check they exist
    items.each do |item|
      expect(redis.exists("partial_payload:analysis_job:#{item}")).to eq(true)
    end

    # decide we don't wan't the partial payloads
    result = BawWorkers::PartialPayload.delete_recursive('analysis_job:10')
    expect(result).to eq(true)

    # check all items do not exist
    items.each do |item|
      expect(redis.exists("partial_payload:analysis_job:#{item}")).to eq(false)
    end
  end
end
