module BawWorkers
  # Runs checks on original audio recording files.
  class AudioFileCheckAction

    include BawWorkers::Common

    # Ensure that there is only one job with the same payload per queue.
    include Resque::Plugins::UniqueJob

    # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
    extend Resque::Plugins::JobStats

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
      BawWorkers::Settings.logger.info(self.name) {
        "Enqueued from AudioFileCheckAction #{audio_params}."
      }
    end

    # Perform work. Used by `resque`.
    # @param [Hash] audio_params
    # @return [Array<String>] target existing paths
    def self.perform(audio_params)
      audio_params_sym = validate(audio_params)
      file_info = get_info_and_check(audio_params_sym)
      file_info
    end

    def self.existing_info(existing_file)
      media_cache_tool = BawWorkers::Settings.media_cache_tool

      # based on how harvester gets file hash.
      # TODO: check is there are file hashes in db without 'SHA256' prefix.
      generated_file_hash = 'SHA256::' + media_cache_tool.generate_hash(existing_file).hexdigest

      # integrity
      integrity_check = media_cache_tool.audio.integrity_check(existing_file)

      # get file info using ffmpeg
      info = media_cache_tool.audio.info(existing_file)

      info_hash = {
          file: existing_file,
          errors: integrity_check.errors,
          file_hash: generated_file_hash,
          media_type: info[:media_type],
          sample_rate_hertz: info[:sample_rate],
          duration_seconds: info[:duration_seconds],
          bit_rate_bps: info[:bit_rate_bps],
          data_length_bytes: info[:data_length_bytes],
          channels: info[:channels],
      }

      BawWorkers::Settings.logger.info(self.name) {
        "Gathered info for existing file #{info_hash}"
      }

      info_hash
    end

    def self.compare(existing_file, given_info)
      existing_file_info = existing_info(existing_file)

      bit_rate_bps_delta = 1000

      file_hash = existing_file_info[:file_hash] == given_info[:file_hash] ? :pass : :fail
      extension = File.extname(existing_file_info[:file]).delete('.') == given_info[:original_format] ? :pass : :fail
      media_type = existing_file_info[:media_type] == given_info[:media_type] ? :pass : :fail

      sample_rate_hertz = existing_file_info[:sample_rate_hertz] == given_info[:sample_rate_hertz] ? :pass : :fail
      channels = existing_file_info[:channels] == given_info[:channels] ? :pass : :fail
      bit_rate_bps = (existing_file_info[:bit_rate_bps] - given_info[:bit_rate_bps]).abs <= bit_rate_bps_delta ? :pass : :fail
      data_length_bytes = existing_file_info[:data_length_bytes] == given_info[:data_length_bytes] ? :pass : :fail
      duration_seconds = existing_file_info[:duration_seconds] == given_info[:duration_seconds] ? :pass : :fail

      file_errors = existing_file_info.errors.size < 1 ? :pass : :fail
      new_file_name = File.basename(existing_file, File.extname(existing_file)).ends_with?('Z') ? :pass : :fail

      {
          actual: existing_file_info,
          expected: given_info,
          checks: {
              file_hash: file_hash,
              extension: extension,
              media_type: media_type,
              sample_rate_hertz: sample_rate_hertz,
              channels: channels,
              bit_rate_bps: bit_rate_bps,
              data_length_bytes: data_length_bytes,
              duration_seconds: duration_seconds,
              file_errors: file_errors,
              new_file_name: new_file_name
          }
      }
    end

    def self.check_and_fix_file(original_paths, existing_file, given_info)
      checks_hash = compare(existing_file, given_info)

    end

    def self.check_and_fix_files(audio_params)

    end

    # @param [Hash] audio_params
    def self.get_info_and_check(audio_params)
      audio_params_sym = validate(audio_params)
      media_cache_tool = BawWorkers::Settings.media_cache_tool

      original_paths = original_paths(audio_params_sym)

      original_paths.existing.each do |existing_file|
        check_and_fix_file(original_paths, existing_file, audio_params)
      end

      # file exists check
      original_exists = original_paths.existing.size > 0


      # TODO: logging and csv file generation.
      # log actions taken: api interaction, files changes, file hash,
      #write_csv()

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

    def self.write_csv(file, hash)
      csv_headers = []
      CSV.open(file, "wb", col_sep: ',', headers: csv_headers, write_headers: true, force_quotes: true) do |csv|
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