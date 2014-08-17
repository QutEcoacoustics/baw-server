shared_context 'media_file' do
  let(:log_file) { "#{@tmp_dir}/spec.log" }

  let(:audio_file_mono) { File.join(File.dirname(__FILE__), '..', '..', 'example_media', 'test-audio-mono.ogg') }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_format) { 'ogg' }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:media_cache_tool) { Settings.media_cache_tool }

  def create_original_audio(media_cache_tool, options, example_file_name)
    original_file_names = media_cache_tool.original_audio_file_names(options)
    original_possible_paths = original_file_names.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten

    FileUtils.mkpath File.dirname(original_possible_paths.first)
    FileUtils.cp example_file_name, original_possible_paths.first
  end

  def get_cached_audio_paths(media_cache_tool, options)
    cache_audio_file = media_cache_tool.cached_audio_file_name(options)
    media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.cache_audio, cache_audio_file)
  end

  def get_cached_spectrogram_paths(media_cache_tool, options)
    cache_spectrogram_file = media_cache_tool.cached_spectrogram_file_name(options)
    media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.cache_spectrogram, cache_spectrogram_file)
  end

end