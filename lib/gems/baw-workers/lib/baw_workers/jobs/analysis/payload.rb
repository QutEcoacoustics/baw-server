# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # class ScriptParams < ::BawWorkers::Dry::SerializedStrictStruct
      #   # @!attribute [r] file_executable
      #   #   @return [String]
      #   attribute :file_executable, ::BawWorkers::Dry::Types::String.optional.default(nil)
      # end

      # Class that handles creating and evaluating analysis payloads.
      class Payload
        # A list of fields invariant to the payload
        BASE_FIELDS = [
          # command to run, with placeholders
          :command_format,
          # Relative path to executable or script to run.
          # This value is OPTIONAL.
          # It exists because when we run analyses, we copy the script/program to run each time.
          # Because the path changes, we need to be able to template the command with the correct absolute path.
          # Examples:
          # command: "mono <{file_executable}> some argument", file_executable: "AP/AP.exe"
          #   ---> result: "mono /mnt/workers/production/runs/123/programs/AP/AP.exe some argument"
          # command: "python <{file_executable}> some argument", file_executable: "analysis_v3.py"
          #   ---> result: "python /mnt/workers/production/runs/123/programs/analysis_v3.py some argument"
          #
          :file_executable,
          # array of paths to copy after running executable file
          :copy_paths,
          # string containing config/settings for executable
          :config,

          # Paths to nest output results.
          # Particularly useful for system jobs the can run multiple analysis and store the output in the same folder.
          :sub_folders
        ].freeze

        # The full list of fields expected in the payload
        OPTS_FIELDS = BASE_FIELDS + [
          # audio recording info
          :uuid,
          :id,
          :datetime_with_offset,
          :original_format,

          # identifier for job (integer or 'system')
          # This field is invariant, but its also useful as a PK so we keep it anyway
          :job_id
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
        ].freeze

        # Create a new BawWorkers::Jobs::Analysis::Payload.
        # @param [Logger] logger
        # @return [BawWorkers::Jobs::Analysis::Payload]
        def initialize(logger)
          @logger = logger
          @class_name = self.class.name
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
          # normalize config
          raw_opts[:config] = get_config(raw_opts)

          # normalize recorded date
          raw_opts[:datetime_with_offset] = get_datetime_with_offset(raw_opts)

          # validate opts
          opts = BawWorkers::Jobs::Analysis::Payload.normalise_opts(raw_opts)

          # validate command placeholders
          BawWorkers::Jobs::Analysis::Runner.check_command_format(opts)

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
          rescue StandardError => e
            @logger.error(@class_name) { e.message }
            raise e
          end

          parsed
        end

        # Get the config string.
        # @param [Hash] raw_opts
        # @return [String] config/settings for executable
        def get_config(raw_opts)
          if raw_opts[:config_file] && raw_opts[:config_string]
            raise ArgumentError, 'Must provide only one of config_file or config_string.'
          end
          if !raw_opts[:config_file] && !raw_opts[:config_string]
            raise ArgumentError, 'Must provide one of config_file or config_string.'
          end

          return raw_opts[:config_string] if raw_opts[:config_string]
          return File.read(raw_opts[:config_file]) if File.exist?(raw_opts[:config_file])

          msg = "Config file #{raw_opts[:config_file]} was not found."
          @logger.error(@class_name) { msg }
          raise ArgumentError, msg
        end

        # Normalize opts so that keys are Symbols and check all required keys are present.
        # @param [Hash] opts
        # @return [Hash] normalized opts
        def self.normalize_opts(opts)
          normalized_keys = BawWorkers::Validation.deep_symbolize_keys(opts)
          BawWorkers::Validation.check_custom_hash(normalized_keys, BawWorkers::Jobs::Analysis::Payload::OPTS_FIELDS)
          normalized_keys
        end
      end
    end
  end
end
