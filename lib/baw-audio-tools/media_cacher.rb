require 'digest'

# This is the class that uses the audio tools and cache tools to cut audio segments
# and generate spectrograms, then save them to the correct path.
module BawAudioTools
  class MediaCacher

    attr_reader :audio, :spectrogram, :cache, :temp_dir

    public

    def initialize(temp_dir)
      @audio = AudioBase.from_executables(
          Settings.audio_tools.ffmpeg_executable,
          Settings.audio_tools.ffprobe_executable,
          Settings.audio_tools.mp3splt_executable,
          Settings.audio_tools.sox_executable,
          Settings.audio_tools.wavpack_executable,
          Settings.cached_audio_defaults,
          temp_dir)
      @spectrogram = Spectrogram.from_executables(
          @audio,
          Settings.audio_tools.imagemagick_convert_executable,
          Settings.audio_tools.imagemagick_identify_executable,
          Settings.cached_spectrogram_defaults,
          temp_dir)
      @cache = CacheBase.from_paths(
          Settings.paths.original_audios,
          Settings.paths.cached_audios,
          Settings.paths.cached_spectrograms,
          Settings.paths.cached_datasets)
      @temp_dir = temp_dir
    end

    def create_audio_segment(modify_parameters = {})
      cache_audio_info = cached_audio_paths(modify_parameters)
      target_existing = cache_audio_info.existing

      if target_existing.blank?
        original_audio_info = original_audio_paths(modify_parameters)

        check_original_paths(
            original_audio_info.possible,
            original_audio_info.existing,
            modify_parameters)

        # create in temp dir to prevent access while creating
        temp_target_existing = @audio.temp_file_from_name(cache_audio_info.file_names.first)
        run_audio_modify(
            original_audio_info.existing.first,
            temp_target_existing,
            modify_parameters)

        # copy to target dirs when finished creating temp file
        copy_media(temp_target_existing, cache_audio_info.possible)

        # delete temp file
        FileUtils.rm(temp_target_existing)

        # update existing paths after cutting audio
        target_existing = check_cached_audio_paths(
            cache_audio_info.file_names.first,
            original_audio_info.existing,
            original_audio_info.possible,
            modify_parameters)
      end

      target_existing
    end

    def generate_spectrogram(modify_parameters = {})
      cache_spectrogram_info = cached_spectrogram_paths(modify_parameters)
      target_existing = cache_spectrogram_info.existing

      if target_existing.blank?
        # create the cached audio segment (it must be a wav file)
        # merge does not include nested hashes, but will actually create a new hash
        # http://thingsaaronmade.com/blog/ruby-shallow-copy-surprise.html
        cached_wav_audio_parameters = {}.merge(modify_parameters)
        cached_wav_audio_parameters[:format] = 'wav'

        # create cached wav audio
        source_existing = create_audio_segment(cached_wav_audio_parameters)

        # create in temp dir to prevent access while creating
        temp_target_existing = @audio.temp_file_from_name(cache_spectrogram_info.file_names.first)
        run_spectrogram_modify(
            source_existing.first,
            temp_target_existing,
            modify_parameters
        )

        # copy to target dirs when finished creating temp file
        copy_media(temp_target_existing, cache_spectrogram_info.possible)

        # delete temp file
        FileUtils.rm(temp_target_existing)

        # update existing paths after generating spectrogram
        target_existing = check_cached_spectrogram_paths(
            cache_spectrogram_info.file_names.first,
            source_existing,
            cache_spectrogram_info.possible,
            modify_parameters)
      end

      target_existing
    end

    def original_audio_paths(modify_parameters = {})
      source_files = self.original_audio_file_names(modify_parameters)

      {
          file_names: source_files,
          possible: source_files.map { |source_file|
            @cache.possible_storage_paths(@cache.original_audio, source_file)
          }.flatten,

          existing: source_files.map { |source_file|
            @cache.existing_storage_paths(@cache.original_audio, source_file)
          }.flatten
      }
    end

    def cached_audio_paths(modify_parameters = {})
      target_file = self.cached_audio_file_name(modify_parameters)

      {
          file_names: [target_file],
          possible: @cache.possible_storage_paths(@cache.cache_audio, target_file),
          existing: @cache.existing_storage_paths(@cache.cache_audio, target_file)
      }
    end

    def cached_spectrogram_paths(modify_parameters = {})
      target_file = self.cached_spectrogram_file_name(modify_parameters)

      {
          file_names: [target_file],
          possible: @cache.possible_storage_paths(@cache.cache_spectrogram, target_file),
          existing: @cache.existing_storage_paths(@cache.cache_spectrogram, target_file)
      }
    end

    # run audio modify to create target using source
    def run_audio_modify(source, target, modify_parameters)
      # ensure the subdirectories exist
      FileUtils.mkpath(File.dirname(target))

      # create the audio segment
      @audio.modify(source, target, modify_parameters)
    end

    # run audio modify to create target using source
    def run_spectrogram_modify(source, target, modify_parameters)
      # create the spectrogram image in target
      # only needs the window, colour, and sample rate (for calculating pixels per second)
      # everything else has already been done

      spectrogram_parameters = {
          window: modify_parameters[:window],
          colour: modify_parameters[:colour],
          sample_rate: modify_parameters[:sample_rate]
      }

      # ensure the subdirectories exist
      FileUtils.mkpath(File.dirname(target))

      # create the spectrogram
      @spectrogram.modify(source, target, spectrogram_parameters)
    end

    def original_audio_file_names(modify_parameters)
      @cache.file_name(@cache.original_audio, modify_parameters)
    end

    def cached_audio_file_name(modify_parameters)
      @cache.file_name(@cache.cache_audio, modify_parameters)
    end

    def cached_spectrogram_file_name(modify_parameters)
      @cache.file_name(@cache.cache_spectrogram, modify_parameters)
    end

    def cached_dataset_file_name(modify_parameters)
      @cache.file_name(@cache.cache_dataset, modify_parameters)
    end

    # @param [string] file_full_path
    # @return [Digest::SHA256] Digest::SHA256 of file
    def generate_hash(file_full_path)
      incr_hash = Digest::SHA256.new

      File.open(file_full_path) do |file|
        buffer = ''

        # Read the file 512 bytes at a time
        until file.eof
          file.read(512, buffer)
          incr_hash.update(buffer)
        end
      end

      incr_hash
    end

    private

    def copy_media(source, targets)
      targets.each do |target|

        # ensure the subdirectories exist
        FileUtils.mkpath(File.dirname(target))

        # copy file to other locations
        FileUtils.cp(source, target)
      end
    end

    def check_original_paths(possible, existing, modify_parameters)
      # if the original audio file()s) cannot be found, raise an exception
      if existing.blank?
        msg = "Could not find original audio in '#{possible}' using #{modify_parameters}."
        fail Exceptions::AudioFileNotFoundError, msg
      end
    end

    def check_cached_audio_paths(file_name, source_existing, target_possible, modify_parameters)
      target_existing_paths = @cache.existing_storage_paths(@cache.cache_audio, file_name)
      if target_existing_paths.blank?
        msg = "Could not create cached audio for #{file_name} from " +
            " #{source_existing} in #{target_possible} using #{modify_parameters}."
        fail Exceptions::AudioFileNotFoundError, msg
      end
      target_existing_paths
    end

    def check_cached_spectrogram_paths(file_name, source_existing, target_possible, modify_parameters)
      target_existing_paths = @cache.existing_storage_paths(@cache.cache_spectrogram, file_name)
      if target_existing_paths.blank?
        msg = "Could not create cached spectrogram for #{file_name} from " +
            " #{source_existing} in #{target_possible} using #{modify_parameters}."
        fail Exceptions::SpectrogramFileNotFoundError, msg
      end
      target_existing_paths
    end

  end
end