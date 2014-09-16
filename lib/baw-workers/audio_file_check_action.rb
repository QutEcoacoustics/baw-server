module BawWorkers
  # Runs checks on original audio recording files.
  class AudioFileCheckAction

    include BawWorkers::Common

    # Ensure that there is only one job with the same payload per queue.
    include Resque::Plugins::UniqueJob

    # Delay when the unique job key is deleted (i.e. when enqueued? becomes false).
    # @return [Fixnum]
    def self.lock_after_execution_period
      30
    end

    # Get the queue for this action. Used by `resque`.
    # @return [Symbol] The queue.
    def self.queue
      BawWorkers::Settings.resque.queues.maintenance
    end

    # Enqueue an audio file check request.
    # @param [Hash] audio_params
    # @return [Boolean] True if job was queued, otherwise false. +nil+ if the job was rejected by a before_enqueue hook
    def self.enqueue(audio_params)
      audio_params_sym = validate(audio_params)
      Resque.enqueue(AudioFileCheckAction, audio_params_sym)
      BawWorkers::Settings.logger.debug("Enqueued from AudioFileCheckAction #{audio_params}.")
    end

    # Perform work. Used by `resque`.
    # @param [Hash] audio_params
    # @return [Array<String>] target existing paths
    def self.perform(audio_params)
      audio_params_sym = validate(audio_params)
      file_info = get_info_and_check(audio_params_sym)
      file_info
    end

    # @param [Hash] audio_params
    def self.get_info_and_check(audio_params)
      audio_params_sym = validate(audio_params)
      media_cache_tool = BawWorkers::Settings.media_cache_tool

      original_paths = original_paths(audio_params_sym)

      # file exists check
      original_exists = original_paths.existing.size > 0

      # file hashes match check
      file_hash_check = compare_hashes(audio_params_sym, original_paths)

      # for each file that is in the old format, rename to new format.
      # use info in original_paths hash.

      # file validity check
      integrity_check_result = integrity_check(original_paths)

      # get info for each existing file
      existing_info = original_paths.existing.map { |file| media_cache_tool.info(file) }

      # file extension and stored mime-type check
      # existing_info

      # Compare values from file with stored values.
      # prefer values from file.
      # sample_rate, channels, bit_rate, data_length_bytes
      # existing_info

      # get duration using ffmpeg and sox.
      # figure out what to use - they're always a little different.
      # existing_info

      # TODO: logging and csv file generation.
      #write_csv()

      recorded_date = Time.zone.parse(audio_recording_hash['recorded_date'])
      uuid = audio_recording_hash['uuid']
      extension = audio_recording_hash['original_extension']
      file_hash = audio_recording_hash['file_hash']
      data_length_bytes = audio_recording_hash['data_length_bytes']
      duration_seconds = audio_recording_hash['duration_seconds']

      @media_cacher = BawAudioTools::MediaCacher.new(BawWorkers::Settings.paths.temp_files)
      cache = @media_cacher
      original_audio = cache.original_audio

      original_file_name = original_audio.file_name_utc(uuid, recorded_date, extension)

      possible_storage_paths = cache.possible_storage_paths(original_audio, original_file_name)
      existing_storage_paths = cache.existing_storage_paths(original_audio, original_file_name)

      if existing_storage_paths.blank?
        msg = "Could not find original audio file #{original_file_name} in #{possible_storage_paths}."
        raise BawAudioTools::Exceptions::AudioFileNotFoundError, msg
      end

      existing_storage_paths.each do |file_full_path|
        file_info = cache.audio.info(file_full_path)
        # TODO: compare file info with stored info, any differences should be updated in database?
      end

    end

    private

    def self.validate(audio_params)
      props = [:id, :uuid, :recorded_date,
               :duration_seconds, :sample_rate_hertz, :channels,
               :bit_rate_bps, :media_type, :data_length_bytes,
               :file_hash, :original_format]

      validate_hash(audio_params)
      audio_params_sym = symbolize_hash_keys(audio_params)

      props.each do |prop|
        fail ArgumentError, "Audio params must include #{prop}." unless audio_params_sym.include?(prop)
      end

      audio_params_sym
    end

    # Get expected and actual file paths
    def self.original_paths(audio_params)
      media_cache_tool = BawWorkers::Settings.media_cache_tool

      modify_parameters = {
          uuid: audio_params.uuid,
          datetime_with_offset: audio_params.recorded_date,
          original_format: audio_params.original_format,
      }

      source_files = media_cache_tool.original_audio_file_names(modify_parameters)
      source_existing_paths = source_files.map { |source_file| media_cache_tool.cache.existing_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten
      source_possible_paths = source_files.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten

      name_old = media_cache_tool.cache.original_audio.file_name(
          modify_parameters.uuid,
          modify_parameters.datetime_with_offset,
          modify_parameters.original_format)

      name_utc = media_cache_tool.cache.original_audio.file_name_utc(
          modify_parameters.uuid,
          modify_parameters.datetime_with_offset,
          modify_parameters.original_format)

      {possible: source_possible_paths, existing: source_existing_paths, name_utc: name_utc, name_old: name_old}
    end

    def self.compare_hashes(audio_params, original_paths)
      media_cache_tool = BawWorkers::Settings.media_cache_tool
      results = []

      # get file hash for each existing file
      given_file_hash = audio_params.file_hash
      original_paths.existing.each do |existing_file|
        # based on how harvester gets file hash.
        # TODO: check is there are file hashes in db without 'SHA256' prefix.
        generated_file_hash = 'SHA256::' + media_cache_tool.generate_hash(existing_file).hexdigest

        # compare hashes ( 0 means equal, -1: left is less, 1: right is less)
        comparison_result = given_file_hash <=> generated_file_hash

        results.push({
                         path: existing_file,
                         given: given_file_hash,
                         generated: generated_file_hash,
                         comparison: comparison_result == 0 ? :match : :different
                     })
      end

      results
    end

    def self.integrity_check(original_paths)
      media_cache_tool = BawWorkers::Settings.media_cache_tool
      results = []
      original_paths.existing.each do |existing_file|
        integrity_check = media_cache_tool.integrity_check(existing_file)
        results.push({path: existing_file, errors: integrity_check.errors})
      end
      results
    end

    def self.write_csv(file, hash)
      csv_headers = []
      CSV.open(file, "wb", col_sep: ',', headers: csv_headers, write_headers: true, force_quotes:true) do |csv|
        # get elements in order
        hash.sort.map do |key, value|

        end
        # csv << ["row", "of", "CSV", "data"]
        # csv << ["another", "row"]
        # ...
      end
    end

  end
end