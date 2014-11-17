module BawWorkers
  module AudioCheck
    class WorkHelper

      def initialize(logger, file_info, api_comm)
        @logger = logger
        @file_info = file_info
        @api_communicator = api_comm

        @class_name = self.class.name
      end

      # Check existing files and modify the file name and/or details via api if necessary.
      # @param [Hash] audio_params
      # @param [Boolean] is_dry_run
      # @return [Array<Hash>] array of hashes representing operations performed
      def run(audio_params, is_dry_run)
        # validate params
        audio_params_sym = BawWorkers::AudioCheck::WorkHelper.validate(audio_params)

        if is_dry_run
          @logger.warn(@class_name) { 'Starting dry run...' }
        else
          @logger.info(@class_name) { 'Starting...' }
        end

        # ensure :recorded_date is an ActiveSupport::TimeWithZone object
        if audio_params_sym[:recorded_date].end_with?('Z')
          audio_params_sym[:recorded_date] = Time.zone.parse(audio_params_sym[:recorded_date])
        else
          fail ArgumentError, ":recorded_date must be a UTC time (i.e. end with Z), given #{audio_params_sym[:recorded_date]}"
        end

        # get the original possible and existing paths, and new and old file names
        original_paths = original_paths(audio_params_sym)

        # HIGH LEVEL PROBLEM: do any audio files exist?
        check_exists(original_paths, audio_params_sym)

        # now check the comparisons for each existing file. Any failures will be logged and fixed if possible.
        result = []
        original_paths[:existing].each do |existing_file|

          # fix all other issues before renaming file
          single_result = run_single(existing_file, audio_params_sym, is_dry_run)

          # LOW LEVEL PROBLEM: rename old file names to new file names
          file_move_info = rename_file(existing_file, original_paths[:name_utc], is_dry_run)

          # record new file location
          result_hash =
              {
                  file_path: existing_file,
                  exists: true,
                  moved_path: file_move_info[:moved] ? file_move_info[:new_file] : nil,
                  compare_hash: single_result[:compare_hash],
                  api_result_hash: single_result[:api_result_hash],
                  api_response: single_result[:api_result]
              }

          result.push(result_hash)

          # create csv info line
          log_csv_line(
              result_hash[:file_path],
              result_hash[:exists],
              result_hash[:moved_path],
              result_hash[:compare_hash],
              result_hash[:api_result_hash],
              result_hash[:api_response],
          )
        end

        @logger.info(@class_name) { '...finished.' }

        result
      end

      # Check an existing file and modify the file name and/or details on website if necessary.
      # @param [String] existing_file
      # @param [Hash] audio_params
      # @param [Boolean] is_dry_run
      # @return [Hash] comparison and api results
      def run_single(existing_file, audio_params, is_dry_run)
        # get existing file info and comparisons between expected and actual
        existing_file_info = @file_info.audio_info(existing_file)

        @logger.debug(@class_name) {
          "Actual file info: #{existing_file_info}"
        }

        compare_hash = compare_info(existing_file, existing_file_info, audio_params)

        base_msg = "for #{compare_hash}"

        @logger.info(@class_name) {
          "Compared expected and actual info #{base_msg}"
        }

        # MID LEVEL PROBLEM: is the file valid?
        # usually will not log 'File integrity uncertain', since the info check will raise an error
        # for most things that would present as 'File integrity uncertain'.
        check_file_integrity = compare_hash[:checks][:file_errors] == :pass
        if check_file_integrity
          @logger.debug(@class_name) {
            "File integrity ok #{base_msg}"
          }
        else
          msg = "File integrity uncertain #{base_msg}"
          @logger.warn(@class_name) { msg }
        end


        # MID LEVEL PROBLEM: extensions do not match
        # (this is impossible, since if the extension/media_type doesn't match,
        # can't find the file in the first place)
        check_extension = compare_hash[:checks][:extension] == :pass
        if check_extension
          @logger.debug(@class_name) {
            "File extensions match #{base_msg}"
          }
        else
          msg = "File extensions do not match #{base_msg}"
          @logger.warn(@class_name) { msg }
        end

        # HIGH LEVEL PROBLEM: do the hashes match?
        # if the hash from params is 'SHA256::' then first check all other checks pass
        # then update it.
        check_file_hash = compare_hash[:checks][:file_hash] == :pass
        is_expected_file_hash_default = compare_hash[:expected][:file_hash] == 'SHA256::'
        if check_file_hash
          @logger.debug(@class_name) {
            "File hashes match #{base_msg}"
          }

        elsif is_expected_file_hash_default
          # do nothing here - raise error if something else doesn't match
        else
          msg = "File hashes DO NOT match #{base_msg}"

          # log error
          @logger.error(@class_name) { msg }

          # write row of csv into log file
          log_csv_line(existing_file, true, nil, compare_hash)

          fail BawAudioTools::Exceptions::FileCorruptError, msg
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

        # check on file hash - if everything else matches, update it. if anything else doesn't
        # match, raise an error
        if is_expected_file_hash_default
          if changed_metadata.size > 0
            msg = "File hash and other properties DO NOT match #{changed_metadata} #{base_msg}"

            # log error
            @logger.error(@class_name) { msg }

            # write row of csv into log file
            log_csv_line(existing_file, true, nil, compare_hash)

            fail BawAudioTools::Exceptions::FileCorruptError, msg
          else
            changed_metadata[:file_hash] = compare_hash[:actual][:file_hash]
          end
        end

        # use api for any changes/updates for low level problems
        update_result = nil
        if changed_metadata.size > 0

          msg = "Update required #{changed_metadata} #{base_msg}"
          @logger.warn(@class_name) { msg }

          if is_dry_run
            @logger.info(@class_name) { 'Dry Run: Would have updated properties.' }
          else
            host = BawWorkers::Settings.api.host
            port = BawWorkers::Settings.api.port

            # get auth token
            auth_token = @api_communicator.request_login

            # update audio recording metadata
            update_result = @api_communicator.update_audio_recording_details(
                'mismatch between file and database',
                existing_file,
                'id',
                changed_metadata,
                auth_token
            )
          end
        else
          @logger.info(@class_name) {
            "No updates required #{base_msg}"
          }
        end

        {
            compare_hash: compare_hash,
            api_result_hash: changed_metadata,
            # nil, true, false
            api_result: (update_result.nil? ? :noaction : update_result ? :success : :error)
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

        BawWorkers::Validation.validate_hash(audio_params)
        audio_params_sym = BawWorkers::Validation.deep_symbolize_keys(audio_params)

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
        original_audio = BawWorkers::Config.original_audio_helper

        modify_parameters = {
            uuid: audio_params[:uuid],
            datetime_with_offset: audio_params[:recorded_date],
            original_format: audio_params[:original_format],
        }

        source_existing_paths = original_audio.existing_paths(modify_parameters)
        source_possible_paths = original_audio.possible_paths(modify_parameters)

        name_old = original_audio.file_name_10(modify_parameters)
        name_utc = original_audio.file_name_utc(modify_parameters)

        {
            possible: source_possible_paths.map { |path| File.expand_path(path) },
            existing: source_existing_paths.map { |path| File.expand_path(path) },
            name_utc: name_utc,
            name_old: name_old
        }
      end

      # Compare expected and actual audio file information.
      # @param [String] existing_file
      # @param [Hash] existing_file_info
      # @param [Hash] audio_params
      # @return [Hash] information about comparison between expected and actual audio file info.
      def compare_info(existing_file, existing_file_info, audio_params)
        correct = :pass
        wrong = :fail

        bit_rate_bps_delta = 1500 # due to difference for asf files of ~ 1300 bps
        duration_seconds_delta = 0.200 # 200 ms due to estimates of duration for mp3 files

        file_hash = existing_file_info[:file_hash].to_s == audio_params[:file_hash].to_s ? correct : wrong
        extension = existing_file_info[:extension].to_s == audio_params[:original_format].to_s ? correct : wrong
        media_type = Mime::Type.lookup(existing_file_info[:media_type]) == Mime::Type.lookup(audio_params[:media_type]) ? correct : wrong

        sample_rate_hertz = existing_file_info[:sample_rate_hertz].to_i == audio_params[:sample_rate_hertz].to_i ? correct : wrong
        channels = existing_file_info[:channels].to_i == audio_params[:channels].to_i ? correct : wrong
        data_length_bytes = existing_file_info[:data_length_bytes].to_i == audio_params[:data_length_bytes].to_i ? correct : wrong

        bit_rate_bps = (existing_file_info[:bit_rate_bps].to_i - audio_params[:bit_rate_bps].to_i).abs <= bit_rate_bps_delta ? correct : wrong
        duration_seconds = (existing_file_info[:duration_seconds].to_f - audio_params[:duration_seconds].to_f).abs <= duration_seconds_delta ? correct : wrong

        file_errors = existing_file_info[:errors].size < 1 ? correct : wrong
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
            bit_rate_bps_delta: bit_rate_bps_delta,
            duration_seconds_delta: duration_seconds_delta
        }
      end

      # Check that at least one original file exists.
      # @param [Hash] original_paths
      # @param [Hash] audio_params
      # @return [void]
      def check_exists(original_paths, audio_params)
        check_file_exists = original_paths[:existing].size > 0

        if check_file_exists
          @logger.debug(@class_name) {
            "Existing files #{original_paths} given #{audio_params}"
          }
        else
          msg = "No existing files for #{original_paths} given #{audio_params}"

          # log error
          @logger.error(@class_name) { msg }

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

        logged_csv_line = BawWorkers::AudioCheck::CsvHelper.logged_csv_line(
            file_path, exists, moved_path,
            compare_hash, api_result_hash, api_response)

        # write to csv
        csv_options = {col_sep: ',', force_quotes: true}

        csv_header_line = logged_csv_line[:headers].to_csv(csv_options).strip
        @logger.fatal(@class_name) { ",#{csv_header_line}" }

        csv_value_line = logged_csv_line[:values].to_csv(csv_options).strip
        @logger.fatal(@class_name) { ",#{csv_value_line}" }
      end

      # Rename file with old file name to new file name.
      # @param [String] existing_file
      # @param [String] file_name_utc
      # @param [Boolean] is_dry_run
      # @return [Hash] action applied to existing file
      def rename_file(existing_file, file_name_utc, is_dry_run)

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
          unless is_dry_run
            FileUtils.move(existing_file, new_path) unless new_path_exists
          end

          # logging
          if new_path_exists
            @logger.info(@class_name) {
              "Found equivalent old and new file names, no action performed. Old: #{existing_file} New: #{new_path}."
            }
          else
            if is_dry_run
              @logger.info(@class_name) {
                "Dry Run: Would have moved #{existing_file} to #{new_path}."
              }
            else
              @logger.info(@class_name) {
                "Moving #{existing_file} to #{new_path}."
              }
            end

          end

          # result details
          {
              old_file: existing_file,
              new_file: new_path,
              moved: !new_path_exists
          }
        end
      end

    end
  end
end