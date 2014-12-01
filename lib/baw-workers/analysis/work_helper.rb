module BawWorkers
  module Analysis
    class WorkHelper

      # Create a new BawWorkers::Analysis::WorkHelper.
      # @param [BawWorkers::Storage::AudioOriginal] original_store
      # @param [BawWorkers::Storage::AnalysisCache] analysis_cache
      # @param [Logger] logger
      # @param [String] temp_dir
      # @return [BawWorkers::Analysis::WorkHelper]
      def initialize(original_store, analysis_cache, logger, temp_dir)
        @original_store = original_store
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
        validate_custom_hash(opts,
                 [
                     :command_format,
                     :uuid,
                     :id,
                     :datetime_with_offset,
                     :original_format,
                     :executable_program,
                     :config_file
                 ])

        working_dir = create_working_dir(opts[:uuid])
        temp_dir = create_temp_dir(opts[:uuid])

        FileUtils.mkpath([working_dir, temp_dir])

        # Get path to original audio file
        if opts.include?(:datetime_with_offset) && !opts[:datetime_with_offset].blank? && !opts[:datetime_with_offset].is_a?(ActiveSupport::TimeWithZone)
          opts[:datetime_with_offset] = Time.zone.parse(opts[:datetime_with_offset].to_s)
        end

        possible_original_files = @original_store.possible_paths(opts)
        existing_original_files = @original_store.existing_paths(opts)

        if existing_original_files.size < 1
          msg = "No original audio files found in #{possible_original_files.join(', ')} using #{opts.to_json}."
          fail BawAudioTools::Exceptions::AudioFileNotFoundError, msg
        end

        # TODO: copy program to temp dir
        # each worker will have a unique temp dir
        # this might need to have content copied from an
        # analysis programs storage location

        # merge source_file, output_dir, and temp_dir into opts
        command_to_run = opts[:command_format]
        if !command_to_run.include?('%{source_file}') || !command_to_run.include?('%{output_dir}') || !command_to_run.include?('%{temp_dir}')
          fail ArgumentError, 'Command line must include placeholders for %{source_file}, %{output_dir}, and %{temp_dir}.'
        end

        modified_opts = opts.merge({
                                       source_file: "#{File.expand_path(existing_original_files[0])}",
                                       output_dir: "#{File.expand_path(working_dir)}",
                                       temp_dir: "#{File.expand_path(temp_dir)}"
                                   })

        # expand relative paths
        if opts.include?(:executable_program)
          modified_opts[:executable_program] = File.expand_path(modified_opts[:executable_program], BawWorkers::Settings.paths.working_dir)
        end

        if opts.include?(:config_file)
          modified_opts[:config_file] = File.expand_path(modified_opts[:config_file], BawWorkers::Settings.paths.working_dir)
        end

        # format command and execute it
        command = command_to_run % modified_opts
        execute_result = execute(command, working_dir)

        {
            execution_result: execute_result,
            arguments: modified_opts
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

        Dir.chdir(BawWorkers::Settings.paths.working_dir) do
          external_program.execute(command, false)
        end
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

      def validate_custom_hash(hash, keys)
        fail ArgumentError, 'Hash must not be blank.' if hash.blank?
        fail ArgumentError, 'Keys must not be empty.' if keys.blank?
        fail ArgumentError, 'Keys must be an array.' unless keys.is_a?(Array)

        keys.each do |key|
          fail ArgumentError, "Hash must include key '#{key}'." unless hash.include?(key)
          fail ArgumentError, "Value in hash for #{key} must not be blank." if hash[key].blank?
        end
      end

    end
  end
end