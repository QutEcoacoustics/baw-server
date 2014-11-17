module BawWorkers
  module Analysis
    class WorkHelper

      # Create a new BawWorkers::Analysis::WorkHelper.
      # @param [BawWorkers::Storage::AnalysisCache] analysis_cache
      # @param [Logger] logger
      # @param [String] temp_dir
      # @return [BawWorkers::Analysis::WorkHelper]
      def initialize(analysis_cache, logger, temp_dir)
        @analysis_cache = analysis_cache
        @logger = logger
        @temp_dir = temp_dir
      end

      # Run an analysis on a single file.
      # opts can contains other parameters specific to the analysis being run.
      # @param [Hash] opts
      # @option opts [String] :command_format (nil) command line format string
      # @option opts [String] :audio_recording_uuid (nil) audio recording uuid
      # @return [Hash] result information
      def run(opts = {})
        validate(opts, :command_format)
        validate(opts, :uuid)

        working_dir = create_working_dir(opts[:uuid])
        temp_dir = create_temp_dir(opts[:uuid])

        FileUtils.mkpath([working_dir, temp_dir])

        # TODO: copy program to temp dir
        # each worker will have a unique temp dir
        # this might need to have content copied from an
        # analysis programs storage location

        command = opts[:command_format] % opts
        execute_result = execute(command, working_dir)

        {
            execution_result: execute_result,
            working_dir: working_dir,
            temp_dir: temp_dir
        }
      end

      def self.validate(value)
        props = [:uuid, :command_format]

        BawWorkers::Validation.validate_hash(value)
        audio_params_sym = BawWorkers::Validation.deep_symbolize_keys(value)

        props.each do |prop|
          fail ArgumentError, "Audio params must include #{prop}." unless audio_params_sym.include?(prop)
        end

        audio_params_sym
      end

      private

      # Execute a command with working directory information.
      # @param [String] command
      # @param [Hash] output_dir
      # @return [Hash] external program execution result hash
      def execute(command, output_dir)
        timeout_sec = 1 * 60 * 60 # 1 hour
        log_file = File.join(output_dir, 'worker.log')

        open_file = File.open(log_file, 'a+')
        open_file.sync = true

        logger = BawWorkers::MultiLogger.new(Logger.new(open_file))
        external_program = BawAudioTools::RunExternalProgram.new(timeout_sec, logger)
        external_program.execute(command, false)
      end

      # create the audio recording uuid folder in the cached analysis jobs directory
      # @param [String] uuid
      # @return [String] full dir
      def create_working_dir(uuid)
        working_dirs = @analysis_cache.possible_paths_file({uuid: uuid}, '')
        fail BawWorkers::Exceptions::AnalysisCacheError, 'No valid analysis cache directories found.' if working_dirs.size < 1

        File.expand_path(working_dirs[0])
      end

      # create a unique input dir in the temp dir
      # @param [String] uuid
      # @return [String] full dir
      def create_temp_dir(uuid)
        normalise_regex = /[^a-z0-9]/i
        current_time = Time.zone.now.utc.iso8601.to_s.downcase.gsub(normalise_regex, '_')
        normalised_name = uuid.to_s.downcase[0..14]
        sub_dir = "#{normalised_name}_#{current_time}"
        File.expand_path(File.join(@temp_dir, sub_dir))
      end

      def validate(hash, key)
        raise ArgumentError, 'Hash must not be blank.' if hash.blank?
        raise ArgumentError, 'Key must not be blank.' if key.blank?
        raise ArgumentError, "Hash must include key '#{key}'." unless hash.include?(key)
        raise ArgumentError, "Value in hash for #{key} must not be blank." if hash[key].blank?
      end

    end
  end
end