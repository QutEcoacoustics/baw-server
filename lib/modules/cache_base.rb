require File.dirname(__FILE__) + '/cache_audio'
require File.dirname(__FILE__) + '/cache_dataset'
require File.dirname(__FILE__) + '/cache_spectrogram'
require File.dirname(__FILE__) + '/original_audio'

# Determines file names for cached and original files.

class CacheBase

  attr_reader :original_audio, :cache_audio, :cache_spectrogram, :cache_dataset

  public

  def initialize(original_audio, cache_audio, cache_spectrogram, cache_dataset)
    # original audio manager
    @original_audio = original_audio

    # other caches
    @cache_audio = cache_audio
    @cache_spectrogram = cache_spectrogram
    @cache_dataset = cache_dataset
  end

  def self.from_paths(original_paths,
      cache_audio_paths, cache_audio_defaults,
      spectrogram_paths, spectrogram_defaults,
      dataset_paths, dataset_defaults)

    original = OriginalAudio.new(original_paths)
    cache_audio = CacheAudio.new(cache_audio_paths, cache_audio_defaults)
    cache_spectrogram = CacheSpectrogram.new(spectrogram_paths, spectrogram_defaults)
    cache_dataset = CacheDataset.new(dataset_paths, dataset_defaults)

    CacheBase.new(original, cache_audio, cache_spectrogram, cache_dataset)
  end

  def self.from_paths_orig(original_paths)
    original = OriginalAudio.new(original_paths)
    CacheBase.new(original, nil, nil, nil)
  end

  def self.from_paths_audio(original_paths, cache_audio_paths, cache_audio_defaults)
    original = OriginalAudio.new(original_paths)
    cache_audio = CacheAudio.new(cache_audio_paths, cache_audio_defaults)
    CacheBase.new(original, cache_audio, nil, nil)
  end

  # get all possible full paths for a file
  def possible_storage_paths(cache_class, file_name)
    check_cache_class(cache_class)
    cache_class.storage_paths.collect { |path| File.join(path, cache_class.partial_path(file_name), file_name) }
  end

  # get the full paths for all existing files that match a file name
  def existing_storage_paths(cache_class, file_name)
    check_cache_class(cache_class)
    possible_paths(cache_class, file_name).find_all { |file| File.exists? file }
  end

  def possible_storage_dirs(cache_class)
    check_cache_class(cache_class)
    cache_class.storage_paths
  end

  def existing_storage_dirs(cache_class)
    check_cache_class(cache_class)
    cache_class.storage_paths.find_all { |dir| Dir.exists? dir }
  end

  ###############################
  # HELPERS
  ###############################

  private

  # get all possible full paths for a file
  def possible_paths(cache_class, file_name)
    cache_class.storage_paths.collect { |path| File.join(path, cache_class.partial_path(file_name), file_name) }
  end

  def check_cache_class(cache_class)
    raise ArgumentError unless !cache_class.nil? && cache_class.respond_to?(:storage_paths) &&
        cache_class.respond_to?(:file_name) && cache_class.respond_to?(:partial_path)
  end
end