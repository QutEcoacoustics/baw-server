require 'spec_helper'

describe BawWorkers::MediaAction do
  include_context 'media_file'

  after(:each) do
    FileUtils.rm_r media_cache_tool.cache.original_audio.storage_paths.first if Dir.exists? media_cache_tool.cache.original_audio.storage_paths.first
    FileUtils.rm_r media_cache_tool.cache.cache_audio.storage_paths.first if Dir.exists? media_cache_tool.cache.cache_audio.storage_paths.first
    FileUtils.rm_r media_cache_tool.cache.cache_spectrogram.storage_paths.first if Dir.exists? media_cache_tool.cache.cache_spectrogram.storage_paths.first
  end

  context 'should execute perform method' do

    it 'raises error when params is not a hash' do
      expect {
        BawWorkers::MediaAction.perform(:audio, 'not a hash')
      }.to raise_error(ArgumentError, /Media request params was not a hash/)
    end

    it 'raises error when media type is invalid' do
      expect {
        BawWorkers::MediaAction.perform(:not_valid_param, {})
      }.to raise_error(ArgumentError, /Media type \(:not_valid_param\) was not valid/)
    end

    context 'generate spectrogram' do

      it 'raises error with bad params' do
        expect {
          BawWorkers::MediaAction.perform(:spectrogram, {})
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

      it 'raises error with bad params' do
        expect {
          BawWorkers::MediaAction.perform(:audio, {})
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