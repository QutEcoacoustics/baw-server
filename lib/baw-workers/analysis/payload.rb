module BawWorkers
  module Analysis

    # Class that handles creating and evaluating analysis payloads.
    class Payload

      OPTS_FIELDS = [
          # command to run, with placeholders
          :command_format,
          # relative path to executable
          :file_executable,
          # array of paths to copy after running executable file
          :copy_paths,
          # string containing config/settings for executable
          :config,
          # identifier for job (integer or 'system')
          :job_id,

          # audio recording info
          :uuid,
          :id,
          :datetime_with_offset,
          :original_format
      ]

      COMMAND_PLACEHOLDERS = [
          # absolute path to source audio file
          :file_source,
          # absolute path to executable
          :file_executable,
          # absolute path to the config file
          :file_config,
          # absolute path to output dir (is also created)
          :dir_output,
          # absolute path to temp dir (is also created)
          :dir_temp
      ]

      # Create a new BawWorkers::Analysis::Payload.
      # @param [Logger] logger
      # @return [BawWorkers::Analysis::Payload]
      def initialize(logger)
        @logger = logger
        @class_name = self.class.name
      end

      # Read a csv file containing audio recording info, and create analysis config files using a template yml file.
      # e.g. bundle exec baw:analysis:standalone:from_csv[settings_file,csv_file,config_file,command_file]
      # @param [String] csv_file
      # @param [String] config_file
      # @param [String] command_file
      # @return [Array<Hash>] analysis payloads
      def from_csv(csv_file, config_file, command_file)
        csv_path = BawWorkers::Validation.normalise_file(csv_file)
        config_path = BawWorkers::Validation.normalise_file(config_file)
        command_path = BawWorkers::Validation.normalise_file(command_file)

        command_info = YAML.load_file(command_path)

        command_format = command_info['command_format']
        file_executable = command_info['file_executable']
        copy_paths = command_info['copy_paths']
        config_string = File.read(config_path)
        job_id = command_info['job_id']

        results = []

        BawWorkers::ReadCsv.read_audio_recording_csv(csv_path) do |audio_params|
          opts = {
              command_format: command_format,
              file_executable: file_executable,
              copy_paths: copy_paths,
              config_string: config_string,
              job_id: job_id,

              uuid: audio_params[:uuid],
              id: audio_params[:id],
              datetime_with_offset: audio_params[:recorded_date],
              original_format: audio_params[:original_format]
          }

          # add analysis payload to results
          result = build(opts)
          results.push(result)
        end

        results
      end

      # Build an analysis task payload.
      # @param [Hash] raw_opts
      # @option raw_opts [String] :command_format (nil) command line format string
      # @option raw_opts [String] :file_executable (nil) executable file path (absolute or relative to dir_working)
      # @option raw_opts [String] :config_file (nil) config file
      # @option raw_opts [String] :config_string (nil) config text
      # @option raw_opts [Array<String>] :copy_paths (nil) paths to copy after running executable
      # @option raw_opts [String, Integer] :job_id (nil) job id
      # @option raw_opts [String] :uuid (nil) audio_recording uuid
      # @option raw_opts [String] :id (nil) audio_recording id
      # @option raw_opts [ActiveSupport::TimeWithZone, String] :datetime_with_offset (nil) audio_recording recorded date
      # @option raw_opts [String] :original_format (nil) audio_recording original_format
      # @return [Hash] analysis task payload
      def build(raw_opts)

        # normalise config
        raw_opts[:config] = get_config(raw_opts)

        # normalise recorded date
        raw_opts[:datetime_with_offset] = get_datetime_with_offset(raw_opts)

        # validate opts
        opts = BawWorkers::Analysis::Payload.normalise_opts(raw_opts)

        # validate command placeholders
        BawWorkers::Analysis::Runner.check_command_format(opts)

        # return the analysis payload
        {
            command_format: opts[:command_format].to_s,
            file_executable: opts[:file_executable].to_s,
            copy_paths: opts[:copy_paths],
            config: opts[:config].to_s,
            job_id: opts[:job_id].to_s,

            uuid: opts[:uuid].to_s,
            id: opts[:id].to_s,
            datetime_with_offset: opts[:datetime_with_offset].iso8601(3),
            original_format: opts[:original_format].to_s
        }
      end

      # Get the recorded date as a ActiveSupport::TimeWithZone.
      # @param [Hash] opts
      # @return [ActiveSupport::TimeWithZone] recording start datetime
      def get_datetime_with_offset(opts)
        begin
          parsed = BawWorkers::Validation.normalise_datetime(opts[:datetime_with_offset])
        rescue => e
          @logger.error(@class_name) { e.message }
          raise e
        end

        parsed
      end

      # Get the config string.
      # @param [Hash] raw_opts
      # @return [String] config/settings for executable
      def get_config(raw_opts)
        fail ArgumentError, 'Must provide only one of config_file or config_string.' if raw_opts[:config_file] && raw_opts[:config_string]
        fail ArgumentError, 'Must provide one of config_file or config_string.' if !raw_opts[:config_file] && !raw_opts[:config_string]

        return raw_opts[:config_string] if raw_opts[:config_string]
        return File.read(raw_opts[:config_file]) if File.exists?(raw_opts[:config_file])

        msg = "Config file #{raw_opts[:config_file]} was not found."
        @logger.error(@class_name) { msg }
        fail ArgumentError, msg
      end

      # Normalise opts so that keys are Symbols and check all required keys are present.
      # @param [Hash] opts
      # @return [Hash] normalised opts
      def self.normalise_opts(opts)
        normalised_keys = BawWorkers::Validation.deep_symbolize_keys(opts)
        BawWorkers::Validation.check_custom_hash(normalised_keys, BawWorkers::Analysis::Payload::OPTS_FIELDS)
        normalised_keys
      end

    end
  end
end
