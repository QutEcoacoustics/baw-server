require 'csv'
module BawWorkers
  class AudioFileCheck

    # include common methods
    include BawWorkers::Common

    def initialize(logger)
      @logger = logger

      # api communication
      @api_communicator = ApiCommunicator.new(logger)
    end

    # Check existing files and modify the file name and/or details via api if necessary.
    # @param [Hash] audio_params
    # @return [Array<String>] updated array of file paths
    def run(audio_params)
      # validate params
      audio_params_sym = BawWorkers::AudioFileCheck.validate(audio_params)

      # get the original possible and existing paths, and new and old file names
      original_paths = original_paths(audio_params_sym)

      # HIGH LEVEL PROBLEM: do any audio files exist?
      check_exists(original_paths, audio_params)

      # now check the comparisons for each existing file. Any failures will be logged and fixed if possible.
      updated_existing_paths = []
      original_paths.existing.each do |existing_file|

        # fix all other issues before renaming file
        results = run_single(existing_file, audio_params)

        # LOW LEVEL PROBLEM: rename old file names to new file names
        file_move_info = rename_file(existing_file, original_paths[:name_utc])

        # create csv info line
        log_csv_line(
            existing_file,
            true,
            file_move_info[:moved] ? file_move_info[:new_file] : nil,
            results[:compare_hash],
            results[:api_result_hash],
            results[:api_result]
        )

        # record new file location
        updated_existing_paths.push(file_move_info[:new_file])
      end

      updated_existing_paths
    end

    # Check an existing file and modify the file name and/or details on website if necessary.
    # @param [String] existing_file
    # @param [Hash] audio_params
    # @return [Hash] comparison and api results
    def run_single(existing_file, audio_params)
      # get existing file info and comparisons between expected and actual
      compare_hash = compare_info(existing_file, audio_params)

      base_msg = "for #{compare_hash}"

      @logger.info(get_class_name) {
        "Compared expected and actual info #{base_msg}"
      }


      # HIGH LEVEL PROBLEM: do the hashes match?
      check_file_hash = compare_hash[:checks][:file_hash] == :pass
      if check_file_hash
        @logger.debug(get_class_name) {
          "File hashes match #{base_msg}"
        }
      else
        msg = "File hashes DOT NOT match #{base_msg}"

        # log error
        @logger.error(get_class_name) { msg }

        # write row of csv into log file
        log_csv_line(existing_file, true, nil, compare_hash)

        fail BawAudioTools::Exceptions::FileCorruptError, msg
      end


      # MID LEVEL PROBLEM: is the file valid?
      check_file_integrity = compare_hash[:checks][:file_errors] == :pass
      if check_file_integrity
        @logger.debug(get_class_name) {
          "File integrity ok #{base_msg}"
        }
      else
        msg = "File integrity uncertain #{base_msg}"
        @logger.warn(get_class_name) { msg }
      end


      # MID LEVEL PROBLEM: extensions do not match
      # (this is impossible, since if the extension/media_type doesn't match,
      # can't find the file in the first place)
      check_extension = compare_hash[:checks][:extension] == :pass
      if check_extension
        @logger.debug(get_class_name) {
          "File extensions match #{base_msg}"
        }
      else
        msg = "File extensions do not match #{base_msg}"
        @logger.warn(get_class_name) { msg }
      end


      changed_metadata = {}

      # LOW LEVEL PROBLEM: media type, sample_rate, channels, bit_rate, data_length_bytes, duration_seconds
      check_media_type = compare_hash[:checks][:media_type] == :pass
      changed_metadata[:media_type] = compare_hash[:actual][:media_type] unless check_media_type

      check_sample_rate = compare_hash[:checks][:sample_rate_hertz] == :pass
      changed_metadata[:sample_rate_hertz] = compare_hash[:actual][:sample_rate_hertz] unless check_sample_rate

      check_channels = compare_hash[:checks][:channels] == :pass
      changed_metadata[:channels] = compare_hash[:actual][:channels] unless check_channels

      check_bit_rate_bps = compare_hash[:checks][:bit_rate_bps] == :pass
      changed_metadata[:bit_rate_bps] = compare_hash[:actual][:bit_rate_bps] unless check_bit_rate_bps

      check_data_length_bytes = compare_hash[:checks][:data_length_bytes] == :pass
      changed_metadata[:data_length_bytes] = compare_hash[:actual][:data_length_bytes] unless check_data_length_bytes

      check_duration_seconds = compare_hash[:checks][:duration_seconds] == :pass
      changed_metadata[:duration_seconds] = compare_hash[:actual][:duration_seconds] unless check_duration_seconds

      # use api for any changes/updates for low level problems
      update_result = nil
      if changed_metadata.size > 0

        msg = "Update required #{changed_metadata} #{base_msg}"
        @logger.warn(get_class_name) { msg }

        host = BawWorkers::Settings.api.host
        port = BawWorkers::Settings.api.port

        # get auth token
        auth_token = @api_communicator.request_login(
            BawWorkers::Settings.api.user_email,
            BawWorkers::Settings.api.user_password,
            host,
            port,
            nil,
            BawWorkers::Settings.endpoints.login
        )

        # update audio recording metadata
        update_result = @api_communicator.update_audio_recording_details(
            'mismatch between file and database',
            existing_file,
            'id',
            changed_metadata,
            host, port, auth_token,
            BawWorkers::Settings.endpoints.audio_recording_update
        )

      else
        @logger.info(get_class_name) {
          "No updates required #{base_msg}"
        }
      end

      {
          compare_hash: compare_hash,
          api_result_hash: changed_metadata,
          # nil, true, false
          api_result: if update_result.nil?
                        :noaction
                      else
                        update_result ? :success : :error
                      end
      }
    end

    # Validate audio params hash
    # @param [Hash] audio_params
    # @return [Hash] audio params hash with keys converted to symbols
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

    private

    # Get expected and actual file paths.
    # @param [Hash] audio_params
    # @return [Hash] info about possible and existing files.
    def original_paths(audio_params)
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

      {
          possible: source_possible_paths.map { |path| File.expand_path(path) },
          existing: source_existing_paths.map { |path| File.expand_path(path) },
          name_utc: name_utc,
          name_old: name_old
      }
    end

    # Get info for an existing file.
    # @param [String] existing_file
    # @return [Hash] information about an existing file
    def existing_info(existing_file)
      media_cache_tool = BawWorkers::Settings.media_cache_tool

      # based on how harvester gets file hash.
      # TODO: are there file hashes in db without 'SHA256' prefix?
      generated_file_hash = 'SHA256::' + media_cache_tool.generate_hash(existing_file).hexdigest

      # integrity
      integrity_check = media_cache_tool.audio.integrity_check(existing_file)

      # get file info using ffmpeg
      info = media_cache_tool.audio.info(existing_file)

      {
          file: existing_file,
          extension: File.extname(existing_file).delete('.'),
          errors: integrity_check.errors,
          file_hash: generated_file_hash,
          media_type: info[:media_type],
          sample_rate_hertz: info[:sample_rate],
          duration_seconds: info[:duration_seconds],
          bit_rate_bps: info[:bit_rate_bps],
          data_length_bytes: info[:data_length_bytes],
          channels: info[:channels],
      }
    end

    # Compare expected and actual audio file information.
    # @param [String] existing_file
    # @param [Hash] audio_params
    # @return [Hash] information about comparison between expected and actual audio file info.
    def compare_info(existing_file, audio_params)
      existing_file_info = existing_info(existing_file)

      correct = :pass
      wrong = :fail
      bit_rate_bps_delta = 1000

      file_hash = existing_file_info[:file_hash] == audio_params[:file_hash] ? correct : wrong
      extension = existing_file_info[:extension] == audio_params[:original_format] ? correct : wrong
      media_type = existing_file_info[:media_type] == audio_params[:media_type] ? correct : wrong

      sample_rate_hertz = existing_file_info[:sample_rate_hertz] == audio_params[:sample_rate_hertz] ? correct : wrong
      channels = existing_file_info[:channels] == audio_params[:channels] ? correct : wrong
      bit_rate_bps = (existing_file_info[:bit_rate_bps] - audio_params[:bit_rate_bps]).abs <= bit_rate_bps_delta ? correct : wrong
      data_length_bytes = existing_file_info[:data_length_bytes] == audio_params[:data_length_bytes] ? correct : wrong
      duration_seconds = existing_file_info[:duration_seconds] == audio_params[:duration_seconds] ? correct : wrong

      file_errors = existing_file_info.errors.size < 1 ? correct : wrong
      new_file_name = File.basename(existing_file, File.extname(existing_file)).end_with?('Z') ? correct : wrong

      {
          actual: existing_file_info,
          expected: audio_params,
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
          },
          bit_rate_bps_delta: bit_rate_bps_delta
      }
    end

    # Check that at least one original file exists.
    # @param [Hash] original_paths
    # @param [Hash] audio_params
    # @return [void]
    def check_exists(original_paths, audio_params)
      check_file_exists = original_paths.existing.size > 0

      if check_file_exists
        @logger.debug(get_class_name) {
          "Existing files #{original_paths} given #{audio_params}"
        }
      else
        msg = "No existing files for #{original_paths} given #{audio_params}"

        # log error
        @logger.error(get_class_name) { msg }

        # write row of csv into log file
        log_csv_line(original_paths[:possible][0], false)

        fail BawAudioTools::Exceptions::FileNotFoundError, msg
      end
    end

    # create and log a single line of CSV from
    # source file, expected vs actual comparisons, api request responses
    # @param [String] file_path
    # @param [Boolean] exists
    # @param [String] moved_path
    # @param [Hash] compare_hash
    # @param [Hash] api_result_hash
    # @return [void]
    def log_csv_line(file_path, exists, moved_path = nil,
                        compare_hash = nil, api_result_hash = nil, api_response = nil)
      csv_headers = [
          :file_path, :exists,

          :moved_path,
          :errors,

          :check_new_file_name, :check_file_errors,

          :check_file_hash, :check_extension, :check_media_type,
          :check_sample_rate_hertz, :check_channels, :check_bit_rate_bps,
          :check_data_length_bytes, :check_duration_seconds,

          :expected_file_hash, :expected_extension, :expected_media_type,
          :expected_sample_rate_hertz, :expected_channels, :expected_bit_rate_bps,
          :expected_data_length_bytes, :expected_duration_seconds,

          :actual_file_hash, :actual_extension, :actual_media_type,
          :actual_sample_rate_hertz, :actual_channels, :actual_bit_rate_bps,
          :actual_data_length_bytes, :actual_duration_seconds,

          :api_media_type,
          :api_sample_rate_hertz, :api_channels, :api_bit_rate_bps,
          :api_data_length_bytes, :api_duration_seconds,

          :api_response
      ]

      csv_values = []

      # file path and exists must always be available
      csv_values[0] = file_path
      csv_values[1] = exists

      # add moved path - this might be nil if the file wasn't moved
      csv_values[2] = moved_path unless moved_path.nil?

      # add all the info from comparison hash if it is available
      unless compare_hash.blank?
        csv_values[3] = compare_hash[:actual][:errors]

        csv_values[4] = compare_hash[:checks][:new_file_name]
        csv_values[5] = compare_hash[:checks][:file_errors]

        csv_values[6] = compare_hash[:checks][:file_hash]
        csv_values[7] = compare_hash[:checks][:extension]
        csv_values[8] = compare_hash[:checks][:media_type]
        csv_values[9] = compare_hash[:checks][:sample_rate_hertz]
        csv_values[10] = compare_hash[:checks][:channels]
        csv_values[11] = compare_hash[:checks][:bit_rate_bps]
        csv_values[12] = compare_hash[:checks][:data_length_bytes]
        csv_values[13] = compare_hash[:checks][:duration_seconds]

        csv_values[14] = compare_hash[:expected][:file_hash]
        csv_values[15] = compare_hash[:expected][:extension]
        csv_values[16] = compare_hash[:expected][:media_type]
        csv_values[17] = compare_hash[:expected][:sample_rate_hertz]
        csv_values[18] = compare_hash[:expected][:channels]
        csv_values[19] = compare_hash[:expected][:bit_rate_bps]
        csv_values[20] = compare_hash[:expected][:data_length_bytes]
        csv_values[21] = compare_hash[:expected][:duration_seconds]

        csv_values[22] = compare_hash[:actual][:file_hash]
        csv_values[23] = compare_hash[:actual][:extension]
        csv_values[24] = compare_hash[:actual][:media_type]
        csv_values[25] = compare_hash[:actual][:sample_rate_hertz]
        csv_values[26] = compare_hash[:actual][:channels]
        csv_values[27] = compare_hash[:actual][:bit_rate_bps]
        csv_values[28] = compare_hash[:actual][:data_length_bytes]
        csv_values[29] = compare_hash[:actual][:duration_seconds]
      end

      # add values from api results
      unless api_result_hash.blank?
        csv_values[30] = api_result_hash.include?(:media_type) ? :updated : :noaction
        csv_values[31] = api_result_hash.include?(:sample_rate_hertz) ? :updated : :noaction
        csv_values[32] = api_result_hash.include?(:channels) ? :updated : :noaction
        csv_values[33] = api_result_hash.include?(:bit_rate_bps) ? :updated : :noaction
        csv_values[34] = api_result_hash.include?(:data_length_bytes) ? :updated : :noaction
        csv_values[35] = api_result_hash.include?(:duration_seconds) ? :updated : :noaction
      end

      # record response from api request
      unless api_response.nil?
        csv_values[36] = api_response
      end

      # write to csv
      csv_options = {col_sep: ',', force_quotes: true}

      csv_header_line = csv_headers.to_csv(csv_options).strip
      @logger.fatal(get_class_name) { csv_header_line }

      csv_value_line = csv_values.to_csv(csv_options).strip
      @logger.fatal(get_class_name) { csv_value_line }
    end

    # Rename file with old file name to new file name.
    # @param [String] existing_file
    # @param [String] file_name_utc
    # @return [Hash] action applied to existing file
    def rename_file(existing_file, file_name_utc)

      existing_name = File.basename(existing_file, File.extname(existing_file))

      # dodgy way of detecting new file name, but seems the most effective
      if existing_name.end_with?('Z')

        {
            old_file: existing_file,
            new_file: existing_file,
            moved: false
        }
      else

        # create corresponding new file name
        new_path = File.join(File.dirname(existing_file), file_name_utc)

        # check if it exists
        new_path_exists = File.exist?(new_path)

        # move old name to new name unless it already exists
        FileUtils.move(existing_file, new_path) unless new_path_exists

        # logging
        if new_path_exists
          @logger.debug(get_class_name) {
            "Found equivalent old and new file names, no action performed. Old: #{existing_file} New: #{new_path}."
          }
        else
          @logger.info(get_class_name) {
            "Moving #{existing_file} to #{new_path}."
          }
        end

        # result details
        {
            old_file: existing_file,
            new_file: new_path,
            moved: !new_path_exists
        }
      end
    end

    def get_class_name
      self.class.name
    end

  end
end