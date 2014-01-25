require 'digest'
require 'digest/md5'
require File.dirname(__FILE__) + '/cache_base'
require File.dirname(__FILE__) + '/spectrogram'
require File.dirname(__FILE__) + '/audio_base'
require File.dirname(__FILE__) + '/exceptions'

# This is the class that uses the audio tools and cache tools to cut audio segments
# and generate spectrograms, then save them to the correct path.
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

    # first check if a cached audio file matches the request
    target_file = self.cached_audio_file_name(modify_parameters)
    target_existing_paths = @cache.existing_storage_paths(@cache.cache_audio, target_file)
    target_possible_paths = @cache.possible_storage_paths(@cache.cache_audio, target_file)

    if target_existing_paths.blank?

      # if no cached audio files exist, try to create them from the original audio
      source_file = self.original_audio_file_name(modify_parameters)
      source_existing_paths = @cache.existing_storage_paths(@cache.original_audio, source_file)
      source_possible_paths = @cache.possible_storage_paths(@cache.original_audio, source_file)

      # if the original audio file()s) cannot be found, raise an exception
      raise Exceptions::AudioFileNotFoundError, "Could not find original audio in '#{source_possible_paths}' using #{modify_parameters}." if source_existing_paths.blank?

      # create the cached audio file in each of the possible paths
      target_possible_paths.each { |target|

        # ensure the subdirectories exist
        FileUtils.mkpath(File.dirname(target))

        # TODO: optimisation: do task once, then copy file to other locations
        # create the audio segment
        @audio.modify(source_existing_paths.first, target, modify_parameters)
      }

      # update existing paths after cutting audio
      target_existing_paths = @cache.existing_storage_paths(@cache.cache_audio, target_file)
      raise Exceptions::AudioFileNotFoundError, "Could not find cached audio for #{target_file} using #{modify_parameters}." if target_existing_paths.blank?
    end

    # the requested audio file should exist in at least one possible path
    # return the first existing full path
    target_existing_paths
  end

  def generate_spectrogram(modify_parameters = {})

    # first check if a cached spectrogram matches the request
    target_file = self.cached_spectrogram_file_name(modify_parameters)
    target_existing_paths = @cache.existing_storage_paths(@cache.cache_spectrogram, target_file)
    target_possible_paths = @cache.possible_storage_paths(@cache.cache_spectrogram, target_file)

    if target_existing_paths.blank?

      # if no cached spectrogram images exist, try to create them from the cached audio
      source_file = self.cached_audio_file_name(modify_parameters)
      source_existing_paths = @cache.existing_storage_paths(@cache.cache_audio, source_file)
      source_possible_paths = @cache.possible_storage_paths(@cache.cache_audio, source_file)

      if source_existing_paths.blank? || !source_file.match(/\.wav/)
        # create the cached audio segment (it must be a wav file)
        cached_wav_audio_parameters = modify_parameters.clone
        cached_wav_audio_parameters[:format] = 'wav'
        self.create_audio_segment(cached_wav_audio_parameters)

        # update existing paths after cutting audio
        source_wav_file = self.cached_audio_file_name(cached_wav_audio_parameters)
        source_existing_paths = @cache.existing_storage_paths(@cache.cache_audio, source_wav_file)
        raise Exceptions::AudioFileNotFoundError, "Could not find or create cached audio for #{target_file} using cached audio file #{source_wav_file}." if source_existing_paths.blank?
      end

      # create the spectrogram image in each of the possible paths
      # do not include the offsets, channel or resampling, since that has been done already in the source audio file
      # only needs the window and colour

      spectrogram_parameters = {
          window: modify_parameters[:window],
          colour: modify_parameters[:colour]
      }

      target_possible_paths.each { |target|

        # ensure the subdirectories exist
        FileUtils.mkpath(File.dirname(target))

        # TODO: optimisation: do task once, then copy file to other locations
        # generate the spectrogram
        @spectrogram.modify(source_existing_paths.first, target, spectrogram_parameters)
      }

      # update existing paths after generating spectrogram
      target_existing_paths = @cache.existing_storage_paths(@cache.cache_spectrogram, target_file)
      raise Exceptions::SpectrogramFileNotFoundError, "Could not find cached spectrogram for #{target_file} using #{modify_parameters}." if target_existing_paths.blank?
    end

    # the requested spectrogram image should exist in at least one possible path
    # return the first existing full path
    target_existing_paths
  end

  def original_audio_file_name(modify_parameters)
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

end
