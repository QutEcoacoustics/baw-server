# frozen_string_literal: true

describe BawWorkers::RedisCommunicator do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  let(:communicator) { BawWorkers::Config.redis_communicator }

  let(:unwrapped_redis) { Redis.new(Settings.redis.connection.to_h) }

  describe 'wraps a basic redis API' do
    it 'can ping' do
      result = communicator.ping

      expect(result).to eq('PONG')
    end

    it 'wraps keys in a namespace' do
      communicator.set('abc', 123)

      expect(unwrapped_redis.exists('baw-workers:abc')).to eq(true)
    end

    it 'allows the key namespace to be configurable' do
      communicator = BawWorkers::RedisCommunicator.new(
        BawWorkers::Config.logger_worker,
        unwrapped_redis,
        namespace: 'boogey-monster'
      )

      communicator.set('123', 'abc')

      expect(unwrapped_redis.exists('boogey-monster:123')).to eq(true)
    end

    it 'wraps the SET command' do
      success = communicator.set('my_object', test: { nested_hash: 123 }, string: 'test')

      expect(success).to eq(true)
      expect(unwrapped_redis.get('baw-workers:my_object')).to eq('{"test":{"nested_hash":123},"string":"test"}')
    end

    it 'wraps the SET command - and can set an expire' do
      out_opts = { expire_seconds: 7200 }
      success = communicator.set('my_object', { test: { nested_hash: 123 }, string: 'test' }, out_opts)

      expect(success).to eq(true)
      expect(unwrapped_redis.ttl('baw-workers:my_object')).to eq(7200)
    end

    it 'returns the full key in opts' do
      out_opts = {}
      success = communicator.set('my_object', { test: 'test' }, out_opts)

      expect(success).to eq(true)
      expect(out_opts[:key]).to eq('baw-workers:my_object')
    end

    it 'wraps the GET command' do
      payload = { 'media_type' => 'spectrogram',
                  'media_request_params' => { 'uuid' => '12140a87-a8df-4a79-ad06-126c6a390110', 'format' => 'png',
                                              'media_type' => 'image/png', 'start_offset' => 18_363.0, 'end_offset' => 18_371.0, 'channel' => 0, 'sample_rate' => 44_100, 'datetime_with_offset' => '2010-10-13T00:00:00.000+10:00', 'original_format' => '.MP3', 'window' => 512, 'window_function' => 'Hamming', 'colour' => 'g' } }

      unwrapped_redis.set('baw-workers:test_get', payload.to_json)

      response = communicator.get('test_get')

      expect(response).to eq(payload)
    end

    it 'wraps the GET command - for missing keys' do
      response = communicator.get('a-key-that-does-not-exist')

      expect(response).to eq(nil)
    end

    it 'handles empty values' do
      set_success = communicator.set('test_empty', nil)
      response = communicator.get('test_empty')

      expect(set_success).to eq(true)
      expect(response).to be_nil

      set_success = communicator.set('test_empty', '')
      response = communicator.get('test_empty')

      expect(set_success).to eq(true)
      expect(response).to eq('')
    end

    it 'wraps the DEL command' do
      unwrapped_redis.set('baw-workers:my_object', '{"test":{"nested_hash":123},"string":"test"}')

      expect(communicator.delete('my_object')).to eq(true)
      expect(unwrapped_redis.exists('baw-workers:my_object')).to eq(false)
    end

    it 'wraps the EXISTS command' do
      unwrapped_redis.set('baw-workers:my_object', '{"test":{"nested_hash":123},"string":"test"}')

      expect(communicator.exists('my_object')).to eq(true)
    end
  end

  describe 'can store a file' do
    include TempFileHelpers::ExampleGroup

    let(:path) { Fixtures.audio_file_mono29 }
    let(:hash) { BawWorkers::Config.file_info.generate_hash(path).hexdigest }
    let(:key) { path.basename }

    it 'can store a file' do
      result = communicator.set_file(key, path)

      expect(result).to eq true
      expect(communicator.exists?(key)).to eq true

      ttl = communicator.ttl(key)
      expect(ttl).to be_within(1).of(60)
    end

    it 'can check a file is present' do
      result = communicator.set_file(key, path)

      expect(result).to eq true
      expect(communicator.exists_file?(key)).to eq true
    end

    it 'can delete a file' do
      expect(communicator.set_file(key, path)).to eq true
      result = communicator.delete_file(key)

      expect(result).to eq true

      expect(communicator.exists?(key)).to eq false
    end

    it 'can fetch a file (to disk)' do
      expect(communicator.set_file(key, path)).to eq true

      dest = temp_file
      result = communicator.get_file(key, dest)

      expect(result).to eq path.size
      expect(dest.size).to eq path.size
      expect(BawWorkers::Config.file_info.generate_hash(dest)).to eq hash
    end

    it 'can fetch a file (to an IO)' do
      expect(communicator.set_file(key, path)).to eq true

      result = false
      buffer = BawWorkers::IO.write_binary_buffer { |io|
        result = communicator.get_file(key, io)
      }

      expect(result).to eq path.size
      expect(buffer.size).to eq path.size
      expect(BawWorkers::IO.hash_sha256_io(buffer)).to eq hash
    end

    it 'won\'t corrupt a file on disk when fetching a file that does not exist' do
      dest = temp_file
      dest.write('testing')
      size = dest.size
      modified = dest.mtime

      result = communicator.get_file('i dont exist', dest)

      expect(result).to eq nil
      expect(dest.size).to eq size
      expect(dest.mtime).to eq modified
      expect(dest.read).to eq 'testing'
    end
  end
end
