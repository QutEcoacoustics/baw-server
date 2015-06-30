module BawWorkers
  module Analysis

    # Run an Analysis action.
    class Runner

      # worker_top_dir: 01, 02, 03, etc...
      # copy programs folder into working dir from <worker_top_dir>/programs
      # working_dir_per_job: <worker_top_dir>/runs/<job_id>_<audio_recording_id>_<timestamp>/
      # <working_dir_per_job>/temp
      # <working_dir_per_job>/programs
      # store log in <working_dir_per_job>
      # store config file in <working_dir_per_job>

      # File name for config file.
      FILE_CONFIG = 'run.config'

      # File name for worker log file.
      FILE_LOG = 'worker.log'

      # directory name for programs that can be run
      DIR_PROGRAMS = 'programs'

      # Create a new Support class.
      # @param [BawWorkers::Storage::AudioOriginal] original_store
      # @param [BawWorkers::Storage::AnalysisCache] analysis_cache
      # @param [Logger] logger
      # @param [String] dir_worker_top
      # @param [String] dir_programs
      # @return [BawWorkers::Analysis::Runner]
      def initialize(original_store, analysis_cache, logger, dir_worker_top, dir_programs)
        @original_store = original_store
        @analysis_cache = analysis_cache
        @logger = logger
        @dir_worker_top = dir_worker_top
        @dir_programs = dir_programs

        @class_name = self.class.name
      end

      # Prepare for a new run.
      # @param [Hash] opts
      # @return [Hash] settings for running worker
      def prepare(opts = {})
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        opts[:datetime_with_offset] = BawWorkers::Validation.normalise_datetime(opts[:datetime_with_offset])

        run_info = create_run_info(opts)

        dir_run = run_info[:dir_run]
        dir_run_temp = run_info[:dir_run_temp]

        # copy programs directory to run dir
        dir_run_programs = copy_programs(dir_run)

        command_opts = {
            file_source: get_file_source(opts),
            file_executable: get_file_executable(dir_run_programs, opts),
            dir_output: create_output_dir(opts),
            file_config: create_config_file(dir_run, opts),
            dir_run: dir_run,
            dir_temp: dir_run_temp
        }

        # format command string
        BawWorkers::Validation.check_custom_hash(command_opts, BawWorkers::Analysis::Payload::COMMAND_PLACEHOLDERS)
        BawWorkers::Analysis::Payload.check_command_format(opts)
        command_opts[:command] = opts[:command_format] % command_opts

        # include path to worker log file
        command_opts[:file_run_log] = run_info[:file_run_log]

        command_opts
      end

      # Execute a command with working directory information.
      # @param [Hash] prepared_opts
      # @param [Hash] opts
      # @return [Hash] external program execution result hash
      def execute(prepared_opts, opts)
        BawWorkers::Validation.check_custom_hash(prepared_opts, BawWorkers::Analysis::Payload::COMMAND_PLACEHOLDERS)
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)
        BawWorkers::Analysis::Payload.check_command_format(opts)

        timeout_sec = 1 * 60 * 60 # 1 hour
        log_file = prepared_opts[:file_run_log]
        dir_run = prepared_opts[:dir_run]
        dir_output = prepared_opts[:dir_output]
        command = prepared_opts[:command]

        current_wd = Dir.pwd
        run_log = Logger.new(log_file)
        logger = BawWorkers::MultiLogger.new(@logger, run_log)

        external_program = BawAudioTools::RunExternalProgram.new(timeout_sec, logger)
        error = nil
        result = {}

        begin
          # change to run dir
          Dir.chdir(dir_run)
          result = external_program.execute(command, true)
        rescue => e
          error = e
          logger.error(@class_name) { "Error executing #{command}: #{e.inspect}." }
          result[:error] = error
        else
          # run if no error
          logger.debug(@class_name) { "Successfully executed #{result}." }
        ensure
          Dir.chdir(current_wd)
        end

        # add standard paths to copy
        opts[:copy_paths] = [] if opts[:copy_paths].blank?
        opts[:copy_paths] = [opts[:copy_paths]] unless opts[:copy_paths].respond_to?(:each)

        opts[:copy_paths].push(BawWorkers::Analysis::Runner::FILE_LOG)
        opts[:copy_paths].push(BawWorkers::Analysis::Runner::FILE_CONFIG)

        # copy files after command is executed
        result[:copy_results] = copy_custom(dir_run, dir_output, opts)

        result
      end

      # Create directory for a run.
      # @param [Hash] opts
      # @return [Hash] paths
      def create_run_info(opts = {})
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        normalise_regex = /[^a-z0-9]/i
        current_time = Time.zone.now.utc.iso8601.to_s.downcase.gsub(normalise_regex, '_')

        dir_run = File.join(@dir_worker_top, 'runs', "#{opts[:job_id]}_#{opts[:id]}_#{current_time}")
        dir_run_temp = File.join(dir_run, 'temp')
        file_run_log = File.join(dir_run, BawWorkers::Analysis::Runner::FILE_LOG)

        FileUtils.mkpath([dir_run, dir_run_temp])

        {
            dir_run: dir_run,
            dir_run_temp: dir_run_temp,
            file_run_log: file_run_log
        }
      end

      # Create directory for run results.
      # @param [Hash] opts
      # @return [String] output dir
      def create_output_dir(opts = {})
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        analysis_store_opts = {
            job_id: opts[:job_id],
            uuid: opts[:uuid],
            sub_folders: []
        }

        dirs_output = @analysis_cache.possible_paths_dir(analysis_store_opts)

        dir_output = File.expand_path(BawWorkers::Validation.normalise_path(dirs_output.first, nil))

        FileUtils.mkpath([dir_output])

        dir_output
      end

      # Save config to file.
      # @param [String] dir_run
      # @param [Hash] opts
      # @return [void]
      def create_config_file(dir_run, opts = {})
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        config_content = opts[:config]
        config_file = File.join(dir_run, BawWorkers::Analysis::Runner::FILE_CONFIG)

        File.open(config_file, 'w') { |file| file.write(config_content) }
      end

      # Get absolute path to source file.
      # @param [Hash] opts
      # @return [String] source file
      def get_file_source(opts = {})
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        file_sources = @original_store.existing_paths(opts)

        if file_sources.empty?
          possible_sources = @original_store.possible_paths(opts)
          msg = "No original audio files found in #{possible_sources.join(', ')} using #{opts.to_json}."
          @logger.error(@class_name) { msg }
          fail BawAudioTools::Exceptions::AudioFileNotFoundError, msg
        end

        File.expand_path(BawWorkers::Validation.normalise_path(file_sources.first, nil))
      end

      # Get absolute path to executable.
      # @param [String] dir_run_programs
      # @param [Hash] opts
      # @return [String] executable path
      def get_file_executable(dir_run_programs, opts = {})
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        file_executable_relative = opts[:file_executable]
        BawWorkers::Validation.normalise_path(file_executable_relative, dir_run_programs)
      end

      # Copy programs directory to run directory.
      # @param [String] dir_run
      # @return [String] programs dir for a run
      def copy_programs(dir_run)
        src = BawWorkers::Validation.normalise_path(@dir_programs, @dir_worker_top)
        fail ArgumentError, "programs path does not exist #{src}" unless Dir.exists?(src)

        dest = BawWorkers::Validation.normalise_path(dir_run, @dir_worker_top)
        FileUtils.cp_r("#{src}", dest)

        File.join(dest, BawWorkers::Analysis::Runner::DIR_PROGRAMS)
      end

      # Copy custom paths to run dir
      # @param [String] dir_run
      # @param [String] dir_output
      # @param [Hash] opts
      # @return [Array<Hash>] copy results
      def copy_custom(dir_run, dir_output, opts = {})
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        copy_paths = opts[:copy_paths]
        copy_paths = [copy_paths] unless copy_paths.respond_to?(:each)

        copy_results = []

        copy_paths.each do |path|
          error = nil

          begin
            src = BawWorkers::Validation.normalise_path(path, dir_run)
            dest = BawWorkers::Validation.normalise_path(path, dir_output)
            FileUtils.cp(src, dest)
          rescue => e
            error = e
          end

          copy_results.push({error: error, source: src, destination: dest})
        end

        copy_results
      end


    end
  end
end