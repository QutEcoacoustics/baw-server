shared_context 'media_file' do

  let(:audio_file_mono) { File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'example_media', 'test-audio-mono.ogg')) }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_format) { 'ogg' }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }
  let(:audio_file_mono_data_length_bytes) { 822281 }
  let(:audio_file_mono_bit_rate_bps) { 239920 }

  let(:audio_file_corrupt) { File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'example_media', 'test-audio-corrupt.ogg')) }

  let(:audio_original) { BawWorkers::Config.original_audio_helper }
  let(:audio_cache) { BawWorkers::Config.audio_cache_helper }
  let(:spectrogram_cache) { BawWorkers::Config.spectrogram_cache_helper }

  let(:duration_range) { 0.11 }

  let(:temp_dir) { BawWorkers::Config.temp_dir }

  after(:each) do
    audio_original.existing_dirs.each { |dir| FileUtils.rm_r dir }
    audio_cache.existing_dirs.each { |dir| FileUtils.rm_r dir }
    spectrogram_cache.existing_dirs.each { |dir| FileUtils.rm_r dir }
  end

  def create_original_audio(options, example_file_name, new_name_style = false)

    # ensure :datetime_with_offset is an ActiveSupport::TimeWithZone object
    if options.include?(:datetime_with_offset) && options[:datetime_with_offset].is_a?(ActiveSupport::TimeWithZone)
      # all good - no op
    elsif options.include?(:datetime_with_offset) && options[:datetime_with_offset].end_with?('Z')
      options[:datetime_with_offset] = Time.zone.parse(options[:datetime_with_offset])
    else
      fail ArgumentError, "recorded_date must be a UTC time (i.e. end with Z), given '#{options[:datetime_with_offset]}'."
    end

    original_file_names = audio_original.file_names(options)
    original_possible_paths = audio_original.possible_paths(options)

    if new_name_style
      file_to_make = original_possible_paths.second
    else
      file_to_make = original_possible_paths.first
    end

    FileUtils.mkpath File.dirname(file_to_make)
    FileUtils.cp example_file_name, file_to_make

    file_to_make
  end

  def get_cached_audio_paths(options)
    audio_cache.possible_paths(options)
  end

  def get_cached_spectrogram_paths(options)
    spectrogram_cache.possible_paths(options)
  end

  def emulate_resque_worker(queue)
    job = Resque.reserve(queue)

    # returns true if job was performed
    job.perform
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