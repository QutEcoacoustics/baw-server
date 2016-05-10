module BawWorkers
  module Analysis

    # Run an Analysis action.
    class Runner

      # File name for config file per run.
      FILE_CONFIG = 'run.config'

      # File name for worker log file per run.
      FILE_LOG = 'worker.log'

      # Overall job success file
      FILE_SUCCESS = 'job.success'

      # Executable failed
      FILE_EXECUTABLE_FAILURE = 'job.analysis_failure'

      # Worker began processing job
      FILE_WORKER_STARTED = 'job.started'

      # directory name for programs that can be run
      DIR_PROGRAMS = 'programs'

      # directory containing files during run
      DIR_RUNS = 'runs'

      # temporary directory in each run directory
      DIR_TEMP = 'temp'

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
      def prepare(opts)
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        opts[:datetime_with_offset] = BawWorkers::Validation.normalise_datetime(opts[:datetime_with_offset])

        # create started file in output dir
        dir_output = create_output_dir(opts)
        started_file = File.join(dir_output, FILE_WORKER_STARTED)
        FileUtils.touch(started_file)

        # create run dir and info
        run_info = create_run_info(opts)

        dir_run = run_info[:dir_run]
        dir_run_temp = run_info[:dir_run_temp]

        # copy programs directory to run dir
        dir_run_programs = copy_programs(dir_run)

        command_opts = {
            file_source: get_file_source(opts),
            file_executable: get_file_executable(dir_run_programs, opts),
            dir_output: dir_output,
            file_config: create_config_file(dir_run, opts),
            dir_run: dir_run,
            dir_temp: dir_run_temp
        }

        # format command string
        BawWorkers::Validation.check_custom_hash(command_opts, BawWorkers::Analysis::Payload::COMMAND_PLACEHOLDERS)
        BawWorkers::Analysis::Runner.check_command_format(opts)
        command_opts[:command] = BawWorkers::Analysis::Runner.format_command(opts, command_opts)

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
        BawWorkers::Analysis::Runner.check_command_format(opts)

        timeout_sec = 2 * 60 * 60 # 2 hours
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

          logger.info(@class_name) { "Executing #{command}." }

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

        # files created
        result[:output_files_created] = []

        # create result file
        if result.include?(:error) && !result[:error].blank?
          # create failure file
          executable_failure_file = File.join(dir_output, FILE_EXECUTABLE_FAILURE)
          FileUtils.touch(executable_failure_file)
          result[:output_files_created].push(FILE_EXECUTABLE_FAILURE)
        else
          # create success file
          success_file = File.join(dir_output, FILE_SUCCESS)
          FileUtils.touch(success_file)
          result[:output_files_created].push(FILE_SUCCESS)
        end

        # remove worker started file
        started_file = File.join(dir_output, FILE_WORKER_STARTED)
        File.delete(started_file) if File.exists?(started_file)

        # include command format
        result[:command_format] = opts[:command_format]

        # finally delete the run directory
        result[:dir_run] = dir_run
        delete_run_dir(dir_run)

        # include the output directory in results
        result[:dir_output] = dir_output

        result
      end

      # Create directory for a run.
      # @param [Hash] opts
      # @return [Hash] paths
      def create_run_info(opts)
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        normalise_regex = /[^a-z0-9]/i
        current_time = Time.zone.now.utc.iso8601.to_s.downcase.gsub(normalise_regex, '_')

        dir_run = File.join(@dir_worker_top, BawWorkers::Analysis::Runner::DIR_RUNS, "#{opts[:job_id]}_#{opts[:id]}_#{current_time}")
        dir_run_temp = File.join(dir_run,  BawWorkers::Analysis::Runner::DIR_TEMP)
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
      def create_output_dir(opts)
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
      # @return [String] config file path
      def create_config_file(dir_run, opts = {})
        BawWorkers::Validation.check_custom_hash(opts, BawWorkers::Analysis::Payload::OPTS_FIELDS)

        config_content = opts[:config]
        config_file = File.join(dir_run, BawWorkers::Analysis::Runner::FILE_CONFIG)

        File.open(config_file, 'w') { |file| file.write(config_content) }

        config_file
      end

      # Get absolute path to source file.
      # @param [Hash] opts
      # @return [String] source file
      def get_file_source(opts)
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
        src = @dir_programs
        fail ArgumentError, "programs path does not exist #{src}" unless Dir.exists?(src)

        dest = BawWorkers::Validation.normalise_path(dir_run, @dir_worker_top)
        FileUtils.cp_r("#{src}", dest)

        dir_run_programs = File.join(dest, BawWorkers::Analysis::Runner::DIR_PROGRAMS)
        BawWorkers::Validation.normalise_path(dir_run_programs, @dir_worker_top)
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

            # copy file to top level of output dir
            dest_file_name = File.basename(path)
            dest = BawWorkers::Validation.normalise_path(dest_file_name, dir_output)
            FileUtils.cp(src, dest)
          rescue => e
            error = e
          end

          copy_results.push({error: error, source: src, destination: dest})
        end

        copy_results
      end

      # Delete the run directory
      # @param [String] run_dir
      # @return [void]
      def delete_run_dir(run_dir)
        # make sure the dir is underneath the runs dir
        runs_dir = File.join(@dir_worker_top, BawWorkers::Analysis::Runner::DIR_RUNS)
        fail ArgumentError, "dir must be in runs dir, given #{run_dir}" unless run_dir.start_with?(runs_dir)

        FileUtils.rm_rf(run_dir)
      end

      # Ensure command format has required placeholders
      # @param [Hash] opts
      # @return [void]
      def self.check_command_format(opts)
        command_format = opts[:command_format]

        # custom placeholders as don't want to accidentally allow sprintf too much power
        # can only contain placeholders for COMMAND_PLACEHOLDERS, but does not need to contain them all.

        # placeholder: <{PLACEHOLDER}>
        # find placeholders and remove surrounding chars
        command_placeholders = BawWorkers::Analysis::Runner.extract_command_placeholders(opts)
        allowed_placeholders = BawWorkers::Analysis::Payload::COMMAND_PLACEHOLDERS

        command_placeholders.each do |command_placeholder|
          unless allowed_placeholders.include?(command_placeholder)
            all_placeholders = allowed_placeholders.join(', ')
            fail ArgumentError, "Command #{command_format} can only contain #{all_placeholders}."
          end
        end

      end

      # Format command string.
      # @param [Hash] opts
      # @param [Hash] command_opts
      # @return [String] formatted command
      def self.format_command(opts, command_opts)
        command_format = opts[:command_format].dup

        command_placeholders = BawWorkers::Analysis::Runner.extract_command_placeholders(opts)
        allowed_placeholders = BawWorkers::Analysis::Payload::COMMAND_PLACEHOLDERS

        command_placeholders.each do |command_placeholder|

          if !command_opts.include?(command_placeholder) ||
              command_opts[command_placeholder].blank?
            fail ArgumentError, "Value not supplied for placeholder #{command_placeholder} in #{command_format}."
          end

          unless allowed_placeholders.include?(command_placeholder)
            fail ArgumentError, "Placeholder #{command_placeholder} is not allowed in #{command_format}."
          end

          placeholder_value = command_opts[command_placeholder]
          command_format.gsub!("<{#{command_placeholder}}>", placeholder_value)
        end

        command_format
      end

      private

      def self.extract_command_placeholders(opts)
        command_format = opts[:command_format]
        # placeholder: <{PLACEHOLDER}>
        # find placeholders and remove surrounding chars
        command_format.scan(/<{.*?}>/i).map { |placeholder| placeholder[2..-3].downcase.to_sym}
      end

    end
  end
end