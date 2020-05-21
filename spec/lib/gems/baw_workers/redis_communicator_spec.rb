# frozen_string_literal: true

require 'workers_helper'

describe BawWorkers::RedisCommunicator do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  let(:redis) { BawWorkers::Config.redis_communicator }

  let(:fake_redis) { Redis.new(HashWithIndifferentAccess.new(BawWorkers::Settings.redis.connection)) }

  context 'wraps a basic redis API' do

    it 'should wrap keys in a namespace' do
      redis.set('abc', 123)

      expect(fake_redis.exists('baw-workers:abc')).to eq(true)
    end

    it 'should allow the key namespace to be configurable' do
      redis = BawWorkers::RedisCommunicator.new(
        BawWorkers::Config.logger_worker,
        fake_redis,
        namespace: 'boogey-monster'
      )

      redis.set('123', 'abc')

      expect(fake_redis.exists('boogey-monster:123')).to eq(true)
    end

    it 'wraps the SET command' do

      success = redis.set('my_object', test: { nested_hash: 123 }, string: 'test')

      expect(success).to eq(true)
      expect(fake_redis.get('baw-workers:my_object')).to eq('{"test":{"nested_hash":123},"string":"test"}')
    end

    it 'wraps the SET command - and can set an expire' do
      out_opts = { expire_seconds: 7200 }
      success = redis.set('my_object', { test: { nested_hash: 123 }, string: 'test' }, out_opts)

      expect(success).to eq(true)
      expect(fake_redis.ttl('baw-workers:my_object')).to eq(7200)
    end

    it 'returns the full key in opts' do
      out_opts = {}
      success = redis.set('my_object', { test: 'test' }, out_opts)

      expect(success).to eq(true)
      expect(out_opts[:key]).to eq('baw-workers:my_object')
    end

    it 'wraps the GET command' do
      payload = { 'media_type' => 'spectrogram', 'media_request_params' => { 'uuid' => '12140a87-a8df-4a79-ad06-126c6a390110', 'format' => 'png', 'media_type' => 'image/png', 'start_offset' => 18_363.0, 'end_offset' => 18_371.0, 'channel' => 0, 'sample_rate' => 44_100, 'datetime_with_offset' => '2010-10-13T00:00:00.000+10:00', 'original_format' => '.MP3', 'window' => 512, 'window_function' => 'Hamming', 'colour' => 'g' } }

      fake_redis.set('baw-workers:test_get', payload.to_json)

      response = redis.get('test_get')

      expect(response).to eq(payload)
    end

    it 'wraps the GET command - for missing keys' do
      response = redis.get('a-key-that-does-not-exist')

      expect(response).to eq(nil)
    end

    it 'handles empty values' do
      set_success = redis.set('test_empty', nil)
      response = redis.get('test_empty')

      expect(set_success).to eq(true)
      expect(response).to be_nil

      set_success = redis.set('test_empty', '')
      response = redis.get('test_empty')

      expect(set_success).to eq(true)
      expect(response).to eq('')
    end

    it 'wraps the DEL command' do
      fake_redis.set('baw-workers:my_object', '{"test":{"nested_hash":123},"string":"test"}')

      expect(redis.delete('my_object')).to eq(true)
      expect(fake_redis.exists('baw-workers:my_object')).to eq(false)
    end

    it 'wraps the EXISTS command' do
      fake_redis.set('baw-workers:my_object', '{"test":{"nested_hash":123},"string":"test"}')

      expect(redis.exists('my_object')).to eq(true)
    end

  end
end
