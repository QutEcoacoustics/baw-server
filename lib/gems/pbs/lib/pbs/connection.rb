# frozen_string_literal: true

module PBS
  # Manges jobs on a PBS cluster
  class Connection
    include Dry::Monads[:result]
    include SSH

    ENV_PBS_O_WORKDIR = 'PBS_O_WORKDIR'
    ENV_PBS_O_QUEUE = 'PBS_O_QUEUE'
    ENV_PBS_JOBNAME = 'PBS_JOBNAME'
    ENV_PBS_JOBID = 'PBS_JOBID'
    ENV_TMPDIR = 'TMPDIR'

    JSON_PARSER_OPTIONS = {
      allow_nan: true,
      symbolize_names: false
    }.freeze

    # names and values as per the qsub format
    # https://manpages.org/qsub
    DEFAULT_RESOURCES = {
      ncpus: '4',
      mem: '16GB',
      walltime: '3600'
    }.freeze

    DEFAULT_ADDITIONAL_ATTRIBUTES = {
      'group_list' => Settings.batch_analysis.primary_group
    }.freeze

    TEMPLATE_PATH = Pathname(__dir__) / 'scripts' / 'job.sh.erb'

    # @return [::SemanticLogger::Logger]
    attr_reader :logger

    # @return [PayloadTransformer]
    attr_reader :payload_transformer

    # @param settings [BawApp::BatchAnalysisSettings]
    def initialize(settings)
      unless settings.instance_of?(BawApp::BatchAnalysisSettings)
        raise ArgumentError,
          'settings must be an instance of BawApp::BatchAnalysisSettings'
      end

      @settings = settings
      @logger = SemanticLogger[PBS::Connection]
      @payload_transformer = PayloadTransformer.new
    end

    # Fetches all statuses for the connection user.
    # @return [::Dry::Monads::Result<::PBS::Models::JobList>]
    def fetch_all_statuses
      # can't use `-u` on qstat because it triggers a double record output in the alternated format 🤦‍♂️
      command = "qselect -u #{settings.connection.username} | qstat -x -f -F JSON"

      execute_safe(command).fmap { |stdout, _stderr|
        hash = JSON.parse(stdout, JSON_PARSER_OPTIONS)
        ::PBS::Models::JobList.new(hash)
      }
    end

    # Fetch a single status.
    # If more than one job matches the search criteria, the first is returned.
    # @param job_id_or_name [String] can contain job_ids or job_names,
    # @return [::Dry::Monads::Result<Array(string,Job)>]
    def fetch_status(job_id_or_name)
      command = "qstat -x -f -F JSON #{job_id_or_name}"

      execute_safe(command).fmap { |stdout, _stderr|
        hash = JSON.parse(stdout, JSON_PARSER_OPTIONS)
        ::PBS::Models::JobList.new(hash).jobs.first
      }
    end

    # Fetches information about the queues currently running on the cluster
    # @return [::Dry::Monads::Result<::PBS::Models::QueueList>]
    def fetch_queue_status
      command = 'qstat -Q -f -F JSON'

      execute_safe(command).fmap { |stdout, _stderr|
        hash = JSON.parse(stdout, JSON_PARSER_OPTIONS)
        ::PBS::Models::QueueList.new(hash)
      }
    end

    # Uses `qsub` to submit a jobs to a PBS cluster.
    # The working_directory will be:
    #   - the directory for the templated script
    #   - the directory for the stdout/stderr log
    #   - the pwd for a job
    # @param script [String] a bash script to execute in the body of the wrapper script
    # @param working_directory [Pathname] where to store the script and the results.
    #   This path will get translated from a local path to a remote path
    # @param options [Hash] job_name, hook points, resource list, & env vars for the job
    # @option options [String] :job_name a name for the job - should not include an extension
    # @option options [String] :report_error_script The script to execute on failure
    # @option options [String] :report_finish_script The script to execute on finishing
    # @option options [String] :report_start_script The script to execute on starting
    # @option options [Hash<Symbol,String>] :env  key value pairs of information made available to the script
    # @option options [Hash<Symbol,String]  :resources resources to request from PBS, names and values as per https://manpages.org/qsub
    # @option options [Boolean] :hold whether to submit the job in a held state (a User hold)
    # @return [::Dry::Monads::Result<String>] the created job id
    def submit_job(script, working_directory, options = {})
      raise ArgumentError, 'script must not be empty' if script.blank?
      raise ArgumentError, 'working_directory is not a Pathname' unless working_directory.is_a?(Pathname)

      now = Time.now
      job_name = options
                 .fetch(:job_name, now.strftime('%Y%m%dT%H%M%S%z'))
                 .gsub(/[^_A-Za-z0-9.]+/, '_')

      # convert working directory to remote path
      Pathname(
        working_directory
       .to_s
       .gsub(/^#{settings.root_data_path_mapping.workbench}/, settings.root_data_path_mapping.cluster.to_s)
      ) => remote_working_directory

      # used to append `.sh` here but it is actually not needed and I prefer
      # the slightly shorter name.
      script_name = job_name.to_s
      script_remote_path = remote_working_directory / script_name

      # template script
      templated_script = template_script(script, now, options)

      # template command, see resources from README.md
      command = template_qsub_command(working_directory, script_remote_path, job_name, options)

      # run all remote commands
      # upload our script
      upload_file(templated_script, destination: script_remote_path)
        # set +x
        .bind { |_| remote_chmod(script_remote_path, '+x') }
        # qsub script
        .bind { |_| execute_safe(command, fail_message: 'submitting job with qsub') }
        # return job status
        .fmap { |stdout, _stderr| stdout.strip }
    end

    # Deletes a job identified by a job id
    # @param job_id [String] the job id
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def cancel_job(job_id)
      command = "qdel -x #{job_id}"

      execute_safe(command, "deleting job #{jobs_id}")
    end

    # Releases a job identified by a job id
    # @param job_id [String] the job id
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def release_job(job_id)
      command = "qrls -x #{job_id}"

      execute_safe(command, "releasing job #{jobs_id}")
    end

    # Deletes all jobs created by the connection user
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def clean_all_jobs
      # select jobs, including historical, by user which we're connecting with
      # then delete each, including historical
      command = "qselect -x -u #{settings.connection.username} | xargs qdel -x"

      execute_safe(command, fail_message: 'cleaning all jobs')
    end

    # Gets max_queued from qmgr.
    # Returns an integer where 0 represents an unset value.
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_max_queued
      #set server max_queued = [u:PBS_GENERIC=50000]
      command = "qmgr -c 'list server max_queued'"

      status, stdout, _stderr = execute(command)

      return Failure("status was non-zero: #{status}") unless status&.zero?

      max_value = parse_qmgr_list(stdout, 'max_queued')

      return Failure('qmgr did not return the max_queued value') if max_value.blank?

      # 🚨DODGY ALERT:🚨 find the first number and assume it is a limit
      number = max_value.match(/\d+/)&.values_at(0)&.first

      Success(number.to_i)
    end

    # Gets max_array_size from qmgr.
    # Returns an integer where 0 represents an unset value.
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_max_array_size
      #set server max_array_size = 20000
      command = "qmgr -c 'list server max_array_size'"

      status, stdout, _stderr = execute(command)

      return Failure("status was non-zero: #{status}") unless status&.zero?

      Success(parse_qmgr_list(stdout, 'max_array_size').to_i)
    end

    # @return [Boolean] true if the connection was established
    def test_connection
      status, stdout, _stderr = execute('echo "PONG"')
      status&.zero? && stdout.start_with?('PONG')
    rescue SSH::TransportError => e
      logger.error('failed to test_connection', exception: e)

      false
    end

    private

    # @param lines [Array<String>]
    # @param search_key [String]
    # @return [String]
    def parse_qmgr_list(lines, search_key)
      lines = lines.split("\n")

      # Server pbs
      #    max_array_size = 20000
      #

      lines.find do |line|
        next if line.start_with?('Server')
        next if line.blank?

        split = line.split('=', 2)

        raise "Unknown qmgr format for `#{line}` in `#{lines}`" unless split.length == 2

        key = split[0].strip
        value = split[1].strip

        return value if key == search_key
      end
    end

    def template_script(script, now, options)
      template = ERB.new(TEMPLATE_PATH.read)
      templated = template.result_with_hash({
        report_error_script: options.fetch(:report_error_script, 'log "NOOP error hook"'),
        report_finish_script: options.fetch(:report_finish_script, 'log "NOOP finish hook"'),
        report_start_script: options.fetch(:report_start_script, 'log "NOOP start hook"'),
        script:,
        date: now.iso8601
      })

      StringIO.new(templated)
    end

    def template_qsub_command(working_directory, script_path, job_name, options)
      env = options.fetch(:env, {})
      additional_attributes = DEFAULT_ADDITIONAL_ATTRIBUTES.merge(options.fetch(:additional_attributes, {}))
      resources = DEFAULT_RESOURCES.merge(options.fetch(:resources, {}))
      queue = settings.default_queue
      project = settings.default_project
      hold = options.fetch(:hold, false)

      # -l <resource list>
      resource_string = resources.map { |key, value| "-l #{key}=#{value}" }.join(' ')

      # -v <variable list>
      env_string = ''
      unless env.empty?
        pairs = env.map { |key, value| "#{key}='#{value}'" }.join(',')
        env_string = "-v \"#{pairs}\""
      end

      # -W <additional attributes>
      additional_attributes_string = ''
      unless additional_attributes.empty?
        pairs = additional_attributes.map { |key, value| "#{key}=#{value}" }.join(',')
        additional_attributes_string = "-W \"#{pairs}\""
      end

      # -q <queue_name>
      queue_string = queue.blank? ? '' : "-q #{queue}"

      # -h
      hold_string = hold ? '-h' : ''

      cd = "cd '#{working_directory}'"
      # -P <project_name>
      # -N <job_name>
      qsub = "qsub -N #{job_name} -P #{project} #{queue_string} #{hold_string} #{resource_string} #{additional_attributes_string} #{env_string} #{script_path}"
      "#{cd} && #{qsub}"
    end
  end
end
