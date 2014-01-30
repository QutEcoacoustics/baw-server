require File.dirname(__FILE__) + '/cache_audio'
require File.dirname(__FILE__) + '/cache_dataset'
require File.dirname(__FILE__) + '/cache_spectrogram'
require File.dirname(__FILE__) + '/original_audio'
require File.dirname(__FILE__) + '/string'

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
      cache_audio_paths,
      spectrogram_paths,
      dataset_paths)

    original = OriginalAudio.new(original_paths)
    cache_audio = CacheAudio.new(cache_audio_paths)
    cache_spectrogram = CacheSpectrogram.new(spectrogram_paths)
    cache_dataset = CacheDataset.new(dataset_paths)

    CacheBase.new(original, cache_audio, cache_spectrogram, cache_dataset)
  end

  def self.from_paths_orig(original_paths)
    original = OriginalAudio.new(original_paths)
    CacheBase.new(original, nil, nil, nil)
  end

  def self.from_paths_audio(original_paths, cache_audio_paths)
    original = OriginalAudio.new(original_paths)
    cache_audio = CacheAudio.new(cache_audio_paths)
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

  def file_name(cache_class, modify_parameters = {})
    check_cache_class(cache_class)

    # check file name arguments before passing to cache class
    msg = 'Required parameter missing:'
    eq_or_gt = 'must be equal to or greater than'
    if cache_class.is_a?(OriginalAudio) || cache_class.is_a?(CacheAudio) || cache_class.is_a?(CacheSpectrogram)
      raise ArgumentError, "#{msg} uuid" unless modify_parameters.include? :uuid
      raise ArgumentError, 'uuid must not be blank' if modify_parameters[:uuid].blank?
    end

    if cache_class.is_a?(CacheDataset) || cache_class.is_a?(CacheAudio) || cache_class.is_a?(CacheSpectrogram)
      raise ArgumentError, "#{msg} format" unless modify_parameters.include? :format
      raise ArgumentError, 'format must not be blank' if modify_parameters[:format].blank?
    end

    if cache_class.is_a?(CacheAudio) || cache_class.is_a?(CacheSpectrogram)
      raise ArgumentError, "#{msg} start_offset" unless modify_parameters.include? :start_offset
      raise ArgumentError, "start_offset #{eq_or_gt} 0: #{modify_parameters[:end_offset]}" unless modify_parameters[:start_offset].to_f >= 0.0

      raise ArgumentError, "#{msg} end_offset" unless modify_parameters.include? :end_offset
      raise ArgumentError, "end_offset (#{modify_parameters[:end_offset]}) must be greater than start_offset (#{modify_parameters[:start_offset]})" if modify_parameters[:start_offset].to_f >= modify_parameters[:end_offset].to_f

      raise ArgumentError, "#{msg} channel" unless modify_parameters.include? :channel
      raise ArgumentError, "channel#{eq_or_gt} 0: #{modify_parameters[:channel]}" unless modify_parameters[:channel].to_i >= 0

      raise ArgumentError, "#{msg} sample_rate" unless modify_parameters.include? :sample_rate
      raise ArgumentError, "sample_rate #{eq_or_gt} 8000: #{modify_parameters[:sample_rate]}" if modify_parameters[:sample_rate].to_i < 8000
    end

    if cache_class.is_a?(OriginalAudio)
      raise ArgumentError, "#{msg} date" unless modify_parameters.include? :date
      raise ArgumentError, 'date must not be blank' if modify_parameters[:date].blank?

      raise ArgumentError, "#{msg} time" unless modify_parameters.include? :time
      raise ArgumentError, 'time must not be blank' if modify_parameters[:time].blank?

      raise ArgumentError, "#{msg} original_format" unless modify_parameters.include? :original_format
      raise ArgumentError, 'original_format must not be blank' if modify_parameters[:original_format].blank?
    end

    if cache_class.is_a?(CacheSpectrogram)
      raise ArgumentError, "#{msg} window" unless modify_parameters.include? :window
      raise ArgumentError, "window must be greater than 0: #{modify_parameters[:window]}" unless modify_parameters[:window].to_i > 0

      raise ArgumentError, "#{msg} colour" unless modify_parameters.include? :colour
      raise ArgumentError, "colour must be a single character: #{modify_parameters[:colour]}" if modify_parameters[:colour].to_s.size != 1
    end

    if cache_class.is_a?(CacheDataset)
      raise ArgumentError, "#{msg} saved_search_id" unless modify_parameters.include? :saved_search_id
      raise ArgumentError, "saved_search_id must be greater than 0: #{modify_parameters[:saved_search_id]}" unless modify_parameters[:saved_search_id].to_i > 0

      raise ArgumentError, "#{msg} dataset_id" unless modify_parameters.include? :dataset_id
      raise ArgumentError, "dataset_id must be greater than 0: #{modify_parameters[:dataset_id]}" unless modify_parameters[:dataset_id].to_i > 0
    end

    # get file name
    file_name = ''

    case cache_class
      when OriginalAudio
        file_name = @original_audio.file_name(
            modify_parameters[:uuid],
            modify_parameters[:date],
            modify_parameters[:time],
            modify_parameters[:original_format]
        )
      when CacheAudio
        file_name = @cache_audio.file_name(
            modify_parameters[:uuid],
            modify_parameters[:start_offset],
            modify_parameters[:end_offset],
            modify_parameters[:channel],
            modify_parameters[:sample_rate],
            modify_parameters[:format]
        )
      when CacheSpectrogram
        file_name = @cache_spectrogram.file_name(
            modify_parameters[:uuid],
            modify_parameters[:start_offset],
            modify_parameters[:end_offset],
            modify_parameters[:channel],
            modify_parameters[:sample_rate],
            modify_parameters[:window],
            modify_parameters[:colour],
            modify_parameters[:format]
        )
      when CacheDataset
        file_name = @cache_dataset.file_name(
            modify_parameters[:saved_search_id],
            modify_parameters[:dataset_id],
            modify_parameters[:format]
        )
      else
        raise ArgumentError, "#{cache_class} was not recognised as a valid cache class."
    end

    file_name
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
    raise ArgumentError, "#{cache_class} is not a valid cache class." unless !cache_class.nil? && cache_class.respond_to?(:storage_paths) &&
        cache_class.respond_to?(:file_name) && cache_class.respond_to?(:partial_path)
  end


end