require 'digest'
require 'digest/md5'
require File.dirname(__FILE__) + '/cache'
require File.dirname(__FILE__) + '/spectrogram'
require File.dirname(__FILE__) + '/audio'
require File.dirname(__FILE__) + '/exceptions'

# This class know about which audio tools to use to convert/segment audio.
# this way the intermediate files can be put in the right spots, rather than temp files.
module MediaCacher
  #include Cache, Spectrogram, Audio, Exceptions

  public

  def self.generate_spectrogram(modify_parameters = {})
    cache = Cache::Cache.new(
        Settings.paths.original_audios,
        Settings.paths.cached_audios,
        nil,
        Settings.paths.cached_spectrograms,
        nil)
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

  def self.create_audio_segment(modify_parameters = {})
    cache = Cache::Cache.new(
        Settings.paths.original_audios,
        Settings.paths.cached_audios,
        nil,
        Settings.paths.cached_spectrograms,
        nil)
    # first check if a cached audio file matches the request
    target_file = cache.cached_audio_file(modify_parameters)
    target_existing_paths = cache.existing_cached_audio_paths(target_file)

    if target_existing_paths.blank?
      # if no cached audio files exist, try to create them from the original audio
      source_file = cache.original_audio_file(modify_parameters)
      source_existing_paths = cache.existing_original_audio_paths(source_file)
      source_possible_paths = cache.possible_original_audio_paths(source_file)

      # if the original audio files cannot be found, raise an exception
      raise Exceptions::AudioFileNotFoundError, "Could not find original audio file for '#{source_file}' in '#{Settings.paths.original_audios}'" if source_existing_paths.blank?

      audio_recording = AudioRecording.where(:id => modify_parameters[:id]).first!

      # check audio file status
      case audio_recording.status
        when :new
          raise "Audio recording is not yet ready to be accessed: #{audio_recording.uuid}."
        when :to_check
          # check the original file hash
          check_file_hash(source_existing_paths.first, audio_recording)
        when :corrupt
          raise "Audio recording is corrupt and cannot be accessed: #{audio_recording.uuid}."
        when :ignore
          raise "Audio recording is ignored and may not be accessed: #{audio_recording.uuid}."
        else
      end

      raise "Audio recording was not ready: #{audio_recording.uuid}." unless audio_recording.status.to_sym == :ready

      # create the cached audio file in each of the possible paths
      target_possible_paths = cache.possible_cached_audio_paths(target_file)
      target_possible_paths.each { |path|
        # ensure the subdirectories exist
        FileUtils.mkpath(File.dirname(path))
        # create the audio segment
        Audio::modify(source_existing_paths.first, path, modify_parameters)
      }
      target_existing_paths = cache.existing_cached_audio_paths(target_file)
    end

    # the requested audio file should exist in at least one possible path
    # return the first existing full path
    target_existing_paths.first
  end

  def self.check_file_hash(file_path, audio_recording)
    # ensure this audio recording needs to be checked
    return if audio_recording.status != :to_check

    # type of hash is at start of hash_to_compare, split using two colons
    hash_type,compare_hash = audio_recording.file_hash.split('::')

    incr_hash = Digest::SHA256.new
    case  hash_type
      when 'MD5'
        # '::Digest::MD5.new' is actually correct, I have no idea what RubyMine is underlining it for >:(
        incr_hash = ::Digest::MD5.new
      else

    end

    File.open(file_path) do|file|
      buffer = ''

      # Read the file 512 bytes at a time
      until file.eof
        file.read(512, buffer)
        incr_hash.update(buffer)
      end
    end

    # if hashes do not match, mark audio recording as corrupt
    if incr_hash.hexdigest.upcase == compare_hash
      audio_recording.status = :ready
      audio_recording.save!
    else
      audio_recording.status = :corrupt
      audio_recording.save!
      raise "Audio recording was not verified successfully: #{audio_recording.uuid}."
    end
  end
end