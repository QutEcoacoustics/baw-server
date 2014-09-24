shared_context 'media_file' do

  let(:audio_file_mono) { File.join(File.dirname(__FILE__), '..', '..', 'example_media', 'test-audio-mono.ogg') }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_format) { 'ogg' }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:media_cache_tool) { BawWorkers::Settings.media_cache_tool }

  after(:each) do
    FileUtils.rm_r media_cache_tool.cache.original_audio.storage_paths.first if Dir.exists? media_cache_tool.cache.original_audio.storage_paths.first
    FileUtils.rm_r media_cache_tool.cache.cache_audio.storage_paths.first if Dir.exists? media_cache_tool.cache.cache_audio.storage_paths.first
    FileUtils.rm_r media_cache_tool.cache.cache_spectrogram.storage_paths.first if Dir.exists? media_cache_tool.cache.cache_spectrogram.storage_paths.first
  end

  def create_original_audio(media_cache_tool, options, example_file_name, new_name_style = false)
    original_file_names = media_cache_tool.original_audio_file_names(options)
    original_possible_paths = original_file_names.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten

    if new_name_style
      file_to_make = original_possible_paths.second
    else
      file_to_make = original_possible_paths.first
    end

    FileUtils.mkpath File.dirname(file_to_make)
    FileUtils.cp example_file_name, file_to_make
  end

  def get_cached_audio_paths(media_cache_tool, options)
    cache_audio_file = media_cache_tool.cached_audio_file_name(options)
    media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.cache_audio, cache_audio_file)
  end

  def get_cached_spectrogram_paths(media_cache_tool, options)
    cache_spectrogram_file = media_cache_tool.cached_spectrogram_file_name(options)
    media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.cache_spectrogram, cache_spectrogram_file)
  end

  def transform_hash(original, options={}, &block)
    original.inject({}) { |result, (key, value)|
      value = if options[:deep] && Hash === value
                transform_hash(value, options, &block)
              else
                if Array === value
                  value.map { |v| transform_hash(v, options, &block) }
                else
                  value
                end
              end
      block.call(result, key, value)
      result
    }
  end

# Convert keys to strings
  def stringify_keys(hash)
    transform_hash(hash) { |hash1, key, value|
      hash1[key.to_s] = value
    }
  end

# Convert keys to strings, recursively
  def deep_stringify_keys(hash)
    transform_hash(hash, :deep => true) { |hash1, key, value|
      if value.is_a?(ActiveSupport::TimeWithZone)
        hash1[key.to_s] = value.iso8601(3)
      else
        hash1[key.to_s] = value
      end

    }
  end

end