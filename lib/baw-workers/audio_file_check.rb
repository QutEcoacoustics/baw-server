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

    # Check existing files and modify the file name and/or details on website if necessary.
    # @param [Hash] audio_params
    # @return [Array<String>] existing paths after moves
    def run(audio_params)
      audio_params_sym = BawWorkers::AudioFileCheck.validate(audio_params)
      original_paths = original_paths(audio_params_sym)

      # HIGH LEVEL PROBLEM: do any audio files exist?
      check_exists(original_paths, audio_params)

      # now check the comparisons for each existing file. Any failures will be logged and fixed if possible.
      original_paths.existing.each do |existing_file|
        run_single(existing_file, audio_params)
      end

      # LOW LEVEL PROBLEM: rename old file names to new file names
      updated_existing = rename_files(original_paths)
      updated_existing
    end

    # Check an existing file and modify the file name and/or details on website if necessary.
    # @param [String] existing_file
    # @param [Hash] audio_params
    # @return [void]
    def run_single(existing_file, audio_params)
      # get existing file info and comparisons between expected and actual
      checks_hash = compare_info(existing_file, audio_params)

      base_msg = "for #{checks_hash}"

      @logger.info(get_class_name) {
        "Compared expected and actual info #{checks_hash}"
      }



      # HIGH LEVEL PROBLEM: do the hashes match?
      check_file_hash = checks_hash[:checks][:file_hash] == :pass
      if check_file_hash
        BawWorkers::Settings.logger.debug(get_class_name) {
          "File hashes match #{base_msg}"
        }
      else
        msg = "File hashes DOT NOT match #{base_msg}"
        BawWorkers::Settings.logger.error(get_class_name) { msg }
        fail BawAudioTools::Exceptions::FileCorruptError, msg
      end


      # MID LEVEL PROBLEM: is the file valid?
      check_file_integrity = checks_hash[:checks][:file_errors] == :pass
      if check_file_integrity
        BawWorkers::Settings.logger.debug(get_class_name) {
          "File integrity ok #{base_msg}"
        }
      else
        msg = "File integrity uncertain #{base_msg}"
        BawWorkers::Settings.logger.warn(get_class_name) { msg }
      end

      # MID LEVEL PROBLEM: extensions do not match
      # (this is impossible, since if the extension/media_type doesn't match,
      # can't find the file in the first place)
      check_extension = checks_hash[:checks][:extension] == :pass
      if check_extension
        BawWorkers::Settings.logger.debug(get_class_name) {
          "File extensions match #{base_msg}"
        }
      else
        msg = "File extensions do not match #{base_msg}"
        BawWorkers::Settings.logger.warn(get_class_name) { msg }
      end

      changed_metadata = {}

      # LOW LEVEL PROBLEM: media type, sample_rate, channels, bit_rate, data_length_bytes, duration_seconds
      check_media_type = checks_hash[:checks][:media_type] == :pass
      changed_metadata[:media_type] = checks_hash[:actual][:media_type] unless check_media_type
      #@store_csv[existing_file][]

      check_sample_rate = checks_hash[:checks][:sample_rate_hertz] == :pass
      changed_metadata[:sample_rate_hertz] = checks_hash[:actual][:sample_rate_hertz] unless check_sample_rate

      check_channels = checks_hash[:checks][:channels] == :pass
      changed_metadata[:channels] = checks_hash[:actual][:channels] unless check_channels

      check_bit_rate_bps = checks_hash[:checks][:bit_rate_bps] == :pass
      changed_metadata[:bit_rate_bps] = checks_hash[:actual][:bit_rate_bps] unless check_bit_rate_bps

      check_data_length_bytes = checks_hash[:checks][:data_length_bytes] == :pass
      changed_metadata[:data_length_bytes] = checks_hash[:actual][:data_length_bytes] unless check_data_length_bytes

      check_duration_seconds = checks_hash[:checks][:duration_seconds] == :pass
      changed_metadata[:duration_seconds] = checks_hash[:actual][:duration_seconds] unless check_duration_seconds

      # use api for any changes/updates for low level problems
      if changed_metadata.size > 0

        msg = "Updates required #{changed_metadata} - #{base_msg}"
        BawWorkers::Settings.logger.warn(get_class_name) { msg }

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
        update_success = @api_communicator.update_audio_recording_details(
            'mismatch between file and database',
            existing_file,
            'id',
            changed_metadata,
            host, port, auth_token,
            BawWorkers::Settings.endpoints.audio_recording_update
        )

      else
        BawWorkers::Settings.logger.debug(get_class_name) {
          "No updates required #{base_msg}"
        }
      end

      # TODO: record any changes made to these properties in @store_csv


    end

    # Write hash to file in csv format.
    # @param [String] csv_file
    # @return [void]
    def write_csv(csv_file)

      # file_hash
      # extension
      # media_type
      # sample_rate_hertz
      # channels
      # bit_rate_bps
      # data_length_bytes
      # duration_seconds

      # file_hash
      # extension
      # media_type
      # sample_rate_hertz
      # channels
      # bit_rate_bps
      # data_length_bytes
      # duration_seconds
      # file_errors
      # new_file_name

      csv_headers = [
          :path, :exists, :file_errors, :moved_path,

          :check_new_file_name, :check_file_errors,
          :check_file_hash, :check_extension, :check_media_type, :check_sample_rate_hertz,
          :check_channels, :check_bit_rate_bps, :check_data_length_bytes, :check_duration_seconds,

          :expected_file_hash, :expected_extension, :expected_media_type, :expected_sample_rate_hertz,
          :expected_channels, :expected_bit_rate_bps, :expected_data_length_bytes, :expected_duration_seconds,

          :actual_file_hash, :actual_extension, :actual_media_type, :actual_sample_rate_hertz,
          :actual_channels, :actual_bit_rate_bps, :actual_data_length_bytes, :actual_duration_seconds
      ]
      csv_options = {col_sep: ',', headers: csv_headers, write_headers: true, force_quotes: true}
      csv_options[:write_headers] = false if File.exists?(csv_file)

      # "a"  Write-only, starts at end of file if file exists, otherwise creates a new file for writing.
      CSV.open(csv_file, 'a', csv_options) do |csv|
        @store_csv.each do |file, properties|
          csv_row = [file] # add path
          properties.each do |key, value|
            column_index = csv_headers.index(key)
            csv_row[column_index] = value unless column_index.nil?
          end
          csv << csv_row
        end
      end
    end

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

    # Check that at least one original file exists.
    # @param [Hash] original_paths
    # @param [Hash] audio_params
    # @return [void]
    def check_exists(original_paths, audio_params)
      check_file_exists = original_paths.existing.size > 0

      if check_file_exists
        BawWorkers::Settings.logger.debug(get_class_name) {
          "Existing files #{original_paths} given #{audio_params}"
        }
      else
        
        # can't write csv file at this point


        msg = "No existing files for #{original_paths} given #{audio_params}"
        BawWorkers::Settings.logger.error(get_class_name) { msg }
        fail BawAudioTools::Exceptions::FileNotFoundError, msg
      end
    end

    # Rename files with old file name to new file name.
    # @param [Hash] original_paths
    # @return [Array<String>] existing paths after moves
    def rename_files(original_paths)
      updated_existing = []
      original_paths.existing.each do |existing_file|
        existing_name = File.basename(existing_file, File.extname(existing_file))
        if existing_name.end_with?('Z')
          updated_existing.push(existing_file)
        else
          # create corresponding new file name
          new_path = File.join(File.dirname(existing_file), original_paths[:name_utc])
          # check if it exists
          new_path_exists = File.exist?(new_path)
          # move old name to new name unless it already exists
          if new_path_exists
            BawWorkers::Settings.logger.debug(get_class_name) {
              "Found equivalent old and new file names, no action performed. Old: #{existing_file} New: #{new_path}."
            }
          else
            BawWorkers::Settings.logger.info(get_class_name) {
              "Moving #{existing_file} to #{new_path}."
            }
            @store_csv[existing_file][:moved_path] = new_path
            FileUtils.move(existing_file, new_path)
            updated_existing.push(new_path)
          end
        end
      end

      updated_existing
    end

    def get_class_name
      self.class.name
    end

  end
end