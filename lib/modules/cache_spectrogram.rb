module Cache
  class CacheSpectrogram

    attr_reader :storage_paths, :defaults

    public

    def initialize(storage_paths, defaults)
      # array of top-level folder paths to store cached spectrograms
      @storage_paths = storage_paths
      # hash of defaults
      @defaults = defaults

      @default_format = 'png'
      @separator = '_'
      @extension_indicator = '.'
    end

    def file_name(uuid, start_offset = 0, end_offset, channel = @defaults[@default_format]['channel'],
        sample_rate = @defaults[@default_format]['sample_rate'], window = @defaults[@default_format]['window'],
        colour = @defaults[@default_format]['colour'], format = @default_format)

      uuid.to_s + @separator +
          start_offset.to_f.to_s + @separator + end_offset.to_f.to_s + @separator +
          channel.to_i.to_s + @separator + sample_rate.to_i.to_s + @separator +
          window.to_i.to_s + @separator + colour.to_s +
          @extension_indicator + format.trim('.', '').to_s
    end

    def partial_path(file_name)
      # prepend first two chars of uuid
      # assume that the file name starts with the uuid, get the first two chars as the sub folder
      file_name[0, 2]
    end

    def generate()
      # first check if a cached spectrogram matches the request

      target_file = cache.cached_spectrogram_file(modify_parameters)
      target_existing_paths = cache.existing_cached_spectrogram_paths(target_file)

      if target_existing_paths.blank?
        # if no cached spectrogram images exist, try to create them from the cached audio (it must be a wav file)
        cached_wav_audio_parameters = modify_parameters.clone
        cached_wav_audio_parameters[:format] = 'wav'

        source_file = cache.cached_audio_file(cached_wav_audio_parameters)
        source_existing_paths = cache.existing_cached_audio_paths(source_file)

        if source_existing_paths.blank?
          # change the format to wav, so spectrograms can be created from the audio
          audio_modify_parameters = modify_parameters.clone
          audio_modify_parameters[:format] = 'wav'

          # if no cached audio files exist, try to create them
          create_audio_segment(audio_modify_parameters)
          source_existing_paths = cache.existing_cached_audio_paths(source_file)
          # raise an exception if the cached audio files could not be created
          raise Exceptions::AudioFileNotFoundError, "Could not generate spectrogram." if source_existing_paths.blank?
        end

        # create the spectrogram image in each of the possible paths
        target_possible_paths = cache.possible_cached_spectrogram_paths(target_file)
        target_possible_paths.each { |path|
          # ensure the subdirectories exist
          FileUtils.mkpath(File.dirname(path))
          # generate the spectrogram
          Spectrogram::generate(source_existing_paths.first, path, modify_parameters)
        }
        target_existing_paths = cache.existing_cached_spectrogram_paths(target_file)

        raise Exceptions::SpectrogramFileNotFoundError, "Could not find spectrogram." if target_existing_paths.blank?
      end

      # the requested spectrogram image should exist in at least one possible path
      # return the first existing full path
      target_existing_paths.first
    end
  end
end