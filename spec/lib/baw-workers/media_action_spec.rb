require 'spec_helper'

describe BawWorkers::MediaAction do
  include_context 'media_file'

  let(:queue_name) { BawWorkers::Settings.resque.queues.media }

  context 'queues' do

    let(:test_media_request_params) { {testing: :testing} }
    let(:expected_payload) {
      {
          'class' => 'BawWorkers::MediaAction',
          'args' => ['audio', {'testing' => 'testing'}]
      }
    }

    it 'works on the media queue' do
      expect(Resque.queue_from_class(BawWorkers::MediaAction)).to eq(queue_name)
    end

    it 'can enqueue' do
      result = BawWorkers::MediaAction.enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      result1 = BawWorkers::MediaAction.enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to eq(true)
      expect(Resque.enqueued?(BawWorkers::MediaAction, :audio, test_media_request_params)).to eq(true)

      result2 = BawWorkers::MediaAction.enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result2).to eq(true)
      expect(Resque.enqueued?(BawWorkers::MediaAction, :audio, test_media_request_params)).to eq(true)

      result3 = BawWorkers::MediaAction.enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result3).to eq(true)
      expect(Resque.enqueued?(BawWorkers::MediaAction, :audio, test_media_request_params)).to eq(true)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(1)

      popped = Resque.pop(queue_name)
      expect(popped).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(0)
    end

  end

  context 'should execute perform method' do

    it 'raises error when params is not a hash' do
      expect {
        BawWorkers::MediaAction.perform(:audio, 'not a hash')
      }.to raise_error(ArgumentError, /Media request params was a 'String'\. It must be a 'Hash'\./)
    end

    it 'raises error when media type is invalid' do
      expect {
        BawWorkers::MediaAction.perform(:not_valid_param, {})
      }.to raise_error(ArgumentError, /Media type 'not_valid_param' is not in list of valid media types/)
    end

    context 'generate spectrogram' do

      it 'raises error with no params' do
        expect {
          BawWorkers::MediaAction.perform(:spectrogram, {})
        }.to raise_error(ArgumentError, /Must provide a value for datetime_with_offset/)
      end

      it 'raises error with some bad params' do
        expect {
          BawWorkers::MediaAction.perform(:spectrogram, {datetime_with_offset: Time.zone.now})
        }.to raise_error(ArgumentError, /CacheBase - Required parameter missing: uuid./)
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
        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono)

        # act
        target_existing_paths = BawWorkers::MediaAction.perform(:spectrogram, media_request_params)

        # assert
        expected_paths = get_cached_spectrogram_paths(media_cache_tool, media_request_params)
        expect(target_existing_paths.size).to eq(1)
        expect(target_existing_paths[0]).to eq(expected_paths[0])

      end

    end

    context 'cut audio' do

      it 'raises error with no params' do
        expect {
          BawWorkers::MediaAction.perform(:audio, {})
        }.to raise_error(ArgumentError, /Must provide a value for datetime_with_offset/)
      end

      it 'raises error with some bad params' do
        expect {
          BawWorkers::MediaAction.perform(:audio, {datetime_with_offset: Time.zone.now})
        }.to raise_error(ArgumentError, /CacheBase - Required parameter missing: uuid./)
      end

      it 'is successful with correct parameters' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                format: 'wav',
                media_type: 'audio/wav',
                start_offset: 5,
                end_offset: 10,
                channel: 0,
                sample_rate: 22050,
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format
            }
        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono)

        # act
        target_existing_paths = BawWorkers::MediaAction.perform(:audio, media_request_params)

        # assert
        expected_paths = get_cached_audio_paths(media_cache_tool, media_request_params)
        expect(target_existing_paths.size).to eq(1)
        expect(target_existing_paths[0]).to eq(expected_paths[0])

      end

    end

  end
end