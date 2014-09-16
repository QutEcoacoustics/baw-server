require 'spec_helper'

describe BawWorkers::AudioFileCheckAction do
  include_context 'media_file'

  let(:queue_name) { BawWorkers::Settings.resque.queues.maintenance }

  let(:test_params) {
    {
        id: 5,
        uuid: '7bb0c719-143f-4373-a724-8138219006d9',
        recorded_date: Time.zone.now,
        duration_seconds: audio_file_mono_duration_seconds,
        sample_rate_hertz: audio_file_mono_sample_rate,
        channels: audio_file_mono_channels,
        bit_rate_bps: 239000,
        media_type: audio_file_mono_media_type.to_s,
        data_length_bytes: 822281,
        file_hash: 'SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891',
        original_format: audio_file_mono_format
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

    it 'is successful with correct parameters' do

      media_request_params =
          {
              uuid: '7bb0c719-143f-4373-a724-8138219006d9',
              format: 'png',
              media_type: 'image/png',
              start_offset: 5,
              end_offset: 10,
              channel: 0,
              sample_rate: 22050,
              datetime_with_offset: Time.zone.now,
              original_format: audio_file_mono_format,
              window: 512,
              window_function: 'Hamming',
              colour: 'g'
          }

      original_params = test_params.dup

      # arrange
      create_original_audio(media_cache_tool, media_request_params, audio_file_mono)

      # act
      result = BawWorkers::AudioFileCheckAction.perform(original_params)

      # assert
      a = 1

    end

    it 'is successful with valid params' do
      BawWorkers::AudioFileCheckAction.perform(test_params)
    end

  end
end