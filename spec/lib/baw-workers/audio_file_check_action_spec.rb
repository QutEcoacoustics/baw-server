require 'spec_helper'

describe BawWorkers::AudioFileCheckAction do
  include_context 'media_file'

  let(:queue_name) { BawWorkers::Settings.resque.queues.maintenance }

  let(:test_params) {
    {
        id: 5,
        uuid: '1234567890abcde',
        recorded_date: Time.zone.now,
        duration_seconds: 7,
        sample_rate_hertz: 22050,
        channels: 2,
        bit_rate_bps: 705000,
        media_type: 'audio/wav',
        data_length_bytes: 40000,
        file_hash: 'SHA256::1234567890',
        original_format: 'mp3'
    }
  }

  context 'queues' do

    let(:expected_payload) {
      {
          class: 'BawWorkers::AudioFileCheckAction',
          args: [test_params]
      }
    }

    it 'works on the media queue' do
      expect(Resque.queue_from_class(BawWorkers::AudioFileCheckAction)).to eq(queue_name)
    end

    it 'can enqueue' do
      result = BawWorkers::AudioFileCheckAction.enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)

      actual = Resque.peek(queue_name)
      # {:a => 1, :b => 2}.stringify_keys.should =~ {"a" => 1, "b" => 2}
      expect(deep_stringify_keys(expected_payload)).to eq(actual)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      result1 = BawWorkers::AudioFileCheckAction.enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to eq(true)
      expect(Resque.enqueued?(BawWorkers::AudioFileCheckAction, test_params)).to eq(true)

      result2 = BawWorkers::AudioFileCheckAction.enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result2).to eq(true)
      expect(Resque.enqueued?(BawWorkers::AudioFileCheckAction, test_params)).to eq(true)

      result3 = BawWorkers::AudioFileCheckAction.enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result3).to eq(true)
      expect(Resque.enqueued?(BawWorkers::AudioFileCheckAction, test_params)).to eq(true)

      actual = Resque.peek(queue_name)
      expect(deep_stringify_keys(expected_payload)).to eq(actual)
      expect(Resque.size(queue_name)).to eq(1)

      popped = Resque.pop(queue_name)
      expect(deep_stringify_keys(expected_payload)).to eq(popped)
      expect(Resque.size(queue_name)).to eq(0)
    end

  end

  context 'should execute perform method' do

    it 'raises error when params is not a hash' do
      expect {
        BawWorkers::AudioFileCheckAction.perform('not a hash')
      }.to raise_error(ArgumentError, /Media request params was not a hash/)
    end

    it 'raises error when required value is missing' do
      expect {
        BawWorkers::AudioFileCheckAction.perform(test_params.except(:original_format))
      }.to raise_error(ArgumentError, /Audio params must include original_format/)
    end

  end
end