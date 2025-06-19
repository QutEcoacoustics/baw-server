# frozen_string_literal: true

require 'shellwords'

module PBS
  # Manges jobs on a PBS cluster
  class Connection
    include Dry::Monads[:result]
    include SSH
    include ::BawApp::Inspector

    inspector excludes: [:@settings, :@key_file, :@logger, :@net_ssh_logger, :@ssh_logger, :@connection,
                         :@status_transformer, :@queue_transformer]

    SAFE_NAME_REGEX = /[^_A-Za-z0-9.]+/

    ENV_PBS_O_WORKDIR = 'PBS_O_WORKDIR'
    ENV_PBS_O_QUEUE = 'PBS_O_QUEUE'
    ENV_PBS_JOBNAME = 'PBS_JOBNAME'
    ENV_PBS_JOBID = 'PBS_JOBID'
    ENV_TMPDIR = 'TMPDIR'

    JOB_ID_REGEX = /(\d+)(\.[-\w]+)?/
    JOB_FINISHED_REGEX = /Job has finished/
    JOB_FINISHED_STATUS = 35
    UNKNOWN_JOB_ID_STATUS = 153
    QDEL_GRACEFUL_STATUSES = [0, JOB_FINISHED_STATUS, UNKNOWN_JOB_ID_STATUS].freeze
    QDEL_INVALID_STATE_STATUS = 168

    JSON_PARSER_OPTIONS = {
      allow_nan: true,
      symbolize_names: false
    }.freeze

    # names and values as per the qsub format
    # https://manpages.org/qsub
    DEFAULT_RESOURCES = {
      ncpus: '1',
      mem: '4GB',
      walltime: '3600'
    }.freeze

    TEMPLATE_PATH = Pathname(__dir__) / 'scripts' / 'job.sh.erb'

    # @return [::SemanticLogger::Logger]
    attr_reader :logger

    attr_reader :instance_tag

    # @return [Pathname]
    attr_reader :bin_path

    # @param settings [BawApp::BatchAnalysisSettings]
    # @param instance_tag [String] a tag to identify this instance of the acoustic workbench
    def initialize(settings, instance_tag)
      unless settings.instance_of?(BawApp::BatchAnalysisSettings)
        raise ArgumentError,
          'settings must be an instance of BawApp::BatchAnalysisSettings'
      end

      raise ArgumentError, 'instance_tag must be a String' unless instance_tag.is_a?(String)

      @settings = settings
      @logger = SemanticLogger[PBS::Connection]
      @instance_tag = instance_tag
      @bin_path = Pathname(settings.pbs.bin_path || '')
    end

    # Fetches all statuses for the connection user.
    # @return [::Dry::Monads::Result<::PBS::Models::JobList>]
    def fetch_all_statuses(skip: nil, take: 25)
      raise ArgumentError, '`skip` must be positive Integer' unless skip.nil? || (skip.is_a?(Integer) && skip.positive?)
      raise ArgumentError, '`take` must be positive Integer' unless take.nil? || (take.is_a?(Integer) && take.positive?)

      username = settings.connection.username
      qselect = "#{pbs_bin('qselect')} -x -u #{username}"
      skip = skip.present? ?  " | tail -n +#{skip + 1}" : ''
      take = take.present? ?  " | head -n #{take}" : ''
      filter = qselect + skip + take
      command = "#{pbs_bin('qstat')} -x -f -F JSON $(#{filter})"

      execute_pbs_command(command).fmap { |result|
        parse_status_payload(result.stdout)
      }
    end

    # Fetch a single status.
    # If more than one job matches the search criteria, the first is returned.
    # @param job_id_or_name [String] can contain job_ids or job_names,
    # @return [::Dry::Monads::Result<::PBS::Models::Job>] a tuple of the job_id and job
    def fetch_status(job_id_or_name)
      raise ArgumentError, 'job_id_or_name must be a String' unless job_id_or_name.is_a?(String)

      command = "#{pbs_bin('qstat')} -x -f -F JSON #{job_id_or_name}"

      execute_pbs_command(command).fmap { |result|
        job_list = parse_status_payload(result.stdout)
        job_list.jobs&.first&.last
      }
    end

    # Parses a status payload.
    # @param payload [String] the payload to parse
    # @return [::PBS::Models::JobList]
    def parse_status_payload(payload)
      status_transformer.call(payload)
    end

    # Fetches information about the queues currently running on the cluster
    # @return [::Dry::Monads::Result<::PBS::Models::QueueList>]
    def fetch_all_queue_statuses
      command = "#{pbs_bin('qstat')} -Q -f -F JSON"

      execute_pbs_command(command).fmap { |result|
        queue_transformer.call(result.stdout)
      }
    end

    # Uses `qsub` to submit a jobs to a PBS cluster.
    # The working_directory will be:
    #   - the directory for the templated script
    #   - the directory for the stdout/stderr log
    #   - the pwd for a job
    # If a job_name is provided it will be used for the job name, script name,
    # and log file. The job name will be prefixed with the instance_tag.
    #
    # | `:job_name` | `:hidden` | job name              | script name      | log file             |
    # |-------------|-----------|-----------------------|------------------|----------------------|
    # | nil         | false     | {tag}_job_{datestamp} | job_{datestamp}  | job_{datestamp}.log  |
    # | nil         | true      | {tag}_job_{datestamp} | .job_{datestamp} | .job_{datestamp}.log |
    # | 'foo'       | false     | {tag}_foo             | foo              | foo.log              |
    # | 'foo'       | true      | {tag}_foo             | .foo             | .foo.log             |
    #
    # There are three job hooks:
    # - `report_start_script`: executed when the job starts, before the main script
    # - `report_finish_script`: executed when the job finishes, after the main script
    # - `report_error_script`: executed when the job fails
    #
    # Both the `report_start_script` and `report_finish_script` are executed in the
    # same script and job as the main script.
    #
    # `report_error_script` occurs when the script has failed from one of
    # non-zero exit status, killed by resource limits, or cancelled. You **cannot**
    # distinguish which event triggered the failure hook within the job.
    # It may also be executing shortly before the script is about to be KILLed
    # so make it quick.
    #
    # @param script [String] a bash script to execute in the body of the wrapper script
    # @param working_directory [Pathname] where to store the script and the results.
    #   This path will get translated from a local path to a remote path
    # @param options [Hash] job_name, hook points, resource list, & env vars for the job
    # @option options [String] :job_name a name for the job - should not include an extension
    # @option options [String] :project_suffix a suffix to append onto the PBS project tag
    # @option options [String] :report_error_script The script to execute on failure
    # @option options [String] :report_finish_script The script to execute on finishing
    # @option options [String] :report_start_script The script to execute on starting
    # @option options [Hash<Symbol,String>] :env  key value pairs of information made available to the script
    # @option options [::PBS::Models::Submit::DynamicResourceList] :resources resources to request from PBS, names and values as per https://manpages.org/qsub
    # @option options [Boolean] :hold whether to submit the job in a held state (a User hold)
    # @option options [Boolean] :hidden whether to hide the script and log on
    #   the filesystem by prefixing the job_name with a dot
    # @return [::Dry::Monads::Result<String>] the created job id.
    def submit_job(script, working_directory, **options)
      raise ArgumentError, 'script must not be empty' if script.blank?
      raise ArgumentError, 'working_directory is not a Pathname' unless working_directory.is_a?(Pathname)

      now = Time.now.utc
      name = options.fetch(:job_name, now.strftime('job_%Y%m%dT%H%M%S%z'))
      name = safe_name(name)

      # job name can't be a parsable number, because PBS will emit the job name
      # as a plain number rather than a string. In the case of `.1` for example,
      # the job name will be `.1` and that breaks the JSON parser
      job_name = "#{instance_tag}_#{name}"
      raise ArgumentError, 'job_name must not be a number' if job_name.match?(/^[.\d]+$/)

      # convert working directory to remote path
      Pathname(
        working_directory
       .to_s
       .gsub(/^#{settings.root_data_path_mapping.workbench}/, settings.root_data_path_mapping.cluster.to_s)
      ) => remote_working_directory

      # Used to append `.sh` here but it is actually not needed and I prefer
      # the slightly shorter name.
      # If hidden then prefix with a dot to hide script (and stdout log)
      script_name = options.fetch(:hidden, false) ? ".#{name}" : name
      script_remote_path = remote_working_directory / script_name

      # template script
      templated_script = template_script(script, now, options)

      # template command, see resources from README.md
      command = template_qsub_command(
        working_directory: remote_working_directory,
        script_path: script_remote_path,
        job_name:,
        options:
      )

      # run all remote commands
      # upload our script
      upload_file(templated_script, destination: script_remote_path)
        # set +x
        .bind { |_| remote_chmod(script_remote_path, '+x') }
        # qsub script
        .bind { |_| execute_pbs_command(command, fail_message: 'submitting job with qsub') }
        # return job status
        .fmap { |result| result.stdout.strip }
    end

    # Check if the cluster knows about a job id or not.
    # @param job_id [String] the job id
    # @return [::Dry::Monads::Result<Boolean>] true if the job exists, false if not
    def job_exists?(job_id)
      command = "#{pbs_bin('qstat')} -x #{job_id} > /dev/null"
      result = execute_pbs_command(command, success_statuses: [0, UNKNOWN_JOB_ID_STATUS])

      status = result.fmap(&:status).value_or(nil)
      return Success(true) if status&.zero?
      return Success(false) if status == UNKNOWN_JOB_ID_STATUS

      # result must be a failure at this point
      result
    end

    # Deletes a job identified by a job id.
    # Fails gracefully if the job has already finished or the job history has cleared the ID (unknown).
    # Generally we're cancelling here to clean or sync our state with the cluster. So if the job is already
    # gone/done we don't care.
    # @param job_id [String] the job id
    # @param wait [Boolean] whether to wait for the job to be finish
    # @param completed [Boolean] whether to delete the job from the completed queue
    # @param force [Boolean] whether to force the job to be deleted
    # @return [::Dry::Monads::Result<Result>] The result of the command.
    def cancel_job(job_id, wait: false, completed: false, force: false)
      options = completed ? '-x' : ''
      options += ' -W force' if force
      command = "#{pbs_bin('qdel')} #{options} #{job_id}"

      command += " && while #{pbs_bin('qstat')} '#{job_id}' &> /dev/null; do echo 'waiting' ; sleep 0.1; done" if wait

      # if the job has already finished by the time we get up to cancelling it
      # we don't want to consider it an error. Just be graceful - it has ended.
      # Same thing for a job that's been cleared from the cluster's history:
      execute_pbs_command(command, fail_message: "deleting job #{job_id}", success_statuses: QDEL_GRACEFUL_STATUSES)
    end

    # Cancels all jobs that belong to the same project.
    # Graceful like `cancel_job`, if the job has already finished or the job history has cleared the ID (unknown).
    # Designed to send fewer commands to the cluster.
    # Does not wait.
    # Clears job history.
    # @param project_suffix [String] the project suffix
    # @return [::Dry::Monads::Result<Result>] The result of the command.
    def cancel_jobs_by_project!(project_suffix)
      raise ArgumentError, 'project_suffix must not be empty' if project_suffix.blank?

      project = project_name(project_suffix)

      # we don't select finished jobs (-x)
      # but we still allow qdel to deleted them to avoid races
      command = "#{pbs_bin('qselect')} -x -P #{project} -u #{settings.connection.username} | xargs --no-run-if-empty #{pbs_bin('qdel')} -x -W force"

      execute_pbs_command(command, fail_message: "deleting jobs by project #{project}",
        success_statuses: QDEL_GRACEFUL_STATUSES)
    end

    # Releases a job identified by a job id
    # @param job_id [String] the job id
    # @return [::Dry::Monads::Result<Result>] The result of the command.
    def release_job(job_id)
      command = "#{pbs_bin('qrls')} #{job_id}"

      execute_pbs_command(command, fail_message: "releasing job #{job_id}")
    end

    # Deletes all jobs created by the connection user
    # @return [::Dry::Monads::Result<Result>] The result of the command.
    def clean_all_jobs
      # select jobs, including historical, by user which we're connecting with
      # then delete each, including historical
      command = "#{pbs_bin('qselect')} -x -u #{settings.connection.username} | xargs --no-run-if-empty #{pbs_bin('qdel')} -x -W force"

      execute_pbs_command(command, fail_message: 'cleaning all jobs')
    end

    # Gets the number of jobs currently enqueued - no matter the state.
    # Even finished jobs are counted against user limits
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_enqueued_count
      command = "#{pbs_bin('qselect')} -u #{settings.connection.username} | wc -l"
      execute_pbs_command(command).fmap { |result| result.stdout&.strip.to_i }
    end

    # Gets the number of jobs currently in the queued states
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_queued_count
      command = "#{pbs_bin('qselect')} -s Q -u #{settings.connection.username} | wc -l"
      execute_pbs_command(command).fmap { |result| result.stdout&.strip.to_i }
    end

    # Gets the number of jobs currently running for the connection user
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_running_count
      command = "#{pbs_bin('qselect')} -s R -u #{settings.connection.username} | wc -l"
      execute_pbs_command(command).fmap { |result| result.stdout&.strip.to_i }
    end

    # Gets max_queued from qmgr.
    # Returns an integer where nil represents an unrestricted or unset value.
    # @return [::Dry::Monads::Result<Integer, nil>] the max_queued value, if set
    def fetch_max_queued
      # https://help.altair.com/2022.1.0/PBS%20Professional/PBSReferenceGuide2022.1.pdf page #368
      # the `u:PBS_GENERIC` is a limit for generic users
      # TODO: do I need to cater for different sorts of limits?
      #set server max_queued = [u:PBS_GENERIC=50000]
      command = "#{pbs_bin('qmgr')} -c 'list server max_queued'"

      result = execute_pbs_command(command, fail_message: 'fetching max_queued')

      return result if result.failure?

      stdout = result.value!.stdout

      max_value = parse_qmgr_list(stdout, 'max_queued')

      # the value hasn't been set
      return Success(nil) if max_value.blank?

      # 🚨DODGY ALERT:🚨 find the first number and assume it is a limit
      number = max_value.match(/\d+/)&.values_at(0)&.first

      parsed = number.to_i
      Success(parsed.zero? ? nil : parsed)
    end

    # Gets max_array_size from qmgr.
    # Returns an integer where `nil` represents an unset value.
    # @return [::Dry::Monads::Result<Integer,nil>]
    def fetch_max_array_size
      #set server max_array_size = 20000
      command = "#{pbs_bin('qmgr')} -c 'list server max_array_size'"

      result = execute_pbs_command(command, fail_message: 'fetching max_array_size')

      return result if result.failure?

      result.value! => status, stdout, _stderr, _message

      return Failure("status was non-zero: #{status}") unless status&.zero?

      parsed = parse_qmgr_list(stdout, 'max_array_size').to_i
      Success(parsed.zero? ? nil : parsed)
    end

    # @return [Boolean] true if the connection was established
    def test_connection
      execute('echo "PONG"') => status, stdout, _stderr, _message
      status&.zero? && stdout.start_with?('PONG')
    rescue Errors::TransportError => e
      logger.error('failed to test_connection', exception: e)

      false
    end

    # Map the exist status returned by PBS to a state recognized
    # by an [AnalysisJobsItem]
    # @param exit_status [Integer] the exit status returned by PBS
    # @return [Symbol] the state
    def self.map_exit_status_to_state(exit_status)
      return nil if exit_status.nil?

      # PBSReferenceGuide2022.1.pdf page RG-377
      return :success if exit_status == ExitStatus::JOB_EXEC_OK
      return :killed if ExitStatus::PBS_SPECIAL.include?(exit_status)
      return :failed if ExitStatus::NORMAL.include?(exit_status)

      return :cancelled if exit_status == ExitStatus::CANCELLED_EXIT_STATUS

      # above 256 is a signal
      return :killed if ExitStatus::SIGNAL_KILL.include?(exit_status)

      raise "Unknown exit status: #{exit_status}"
    end

    # Provides a short textual description for an exit status
    # @param exit_status [Integer] the exit status returned by PBS
    # @return [String,nil] the description
    def self.map_exit_status_to_reason(exit_status)
      ExitStatus.map(exit_status)
    end

    private

    # executes a command on the remote PBS cluster via ssh, but will
    # lift some errors into specific PBS error types for better handling
    # @param command [String] the command to execute
    # @param fail_message [String,nil] a message to add to the failure if the command fails
    # @param success_statuses [Array<Integer>] the exit statuses that are considered successful
    # @return [::Dry::Monads::Result<Result>]
    def execute_pbs_command(command, fail_message: nil, success_statuses: SUCCESS_STATUSES)
      execute_safe(command, fail_message:, success_statuses:)
        .or do |error|
          # Some Errors we want to lift into specific PBS error types for better handling
          new_error = Errors::InvalidStateError.wrap(error) ||
                      Errors::ConnectionRefusedError.wrap(error) ||
                      Errors::JobNotFoundError.wrap(error) ||
                      error

          Failure(new_error)
        end
    end

    def status_transformer
      @status_transformer ||= PBS::Transformers::StatusTransformer.new
    end

    def queue_transformer
      @queue_transformer ||= PBS::Transformers::QueueTransformer.new
    end

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
      template = ERB.new(TEMPLATE_PATH.read, trim_mode: '-')
      templated = template.result_with_hash({
        report_finish_script: split_into_lines(options.fetch(:report_finish_script, 'log "NOOP finish hook"')),
        report_start_script: split_into_lines(options.fetch(:report_start_script, 'log "NOOP start hook"')),
        report_error_script: split_into_lines(options.fetch(:report_error_script, 'log "NOOP error hook"')),
        script:,
        date: now.iso8601,
        instance_tag:,
        prelude_script: split_into_lines(settings.pbs.prelude_script)
      })

      StringIO.new(templated)
    end

    def template_qsub_command(
      working_directory:, script_path:, job_name:, options:
    )
      env = options.fetch(:env, {})
      additional_attributes = default_additional_attributes.merge(options.fetch(:additional_attributes, {}))
      resources = DEFAULT_RESOURCES.merge(options.fetch(:resources, {}))
      hold = options.fetch(:hold, false)

      # -h whether or not to hold the job on submit
      hold_string = hold ? '-h' : ''

      # -o <output_path> - change the name of the output file
      # we're adding a .log extension to make filtering of the directory easier
      # "If path is relative, it is taken to be relative to the current working directory of the qsub command"
      # If job is hidden, prefix with a dot to hide log from filesystem
      output = "-o '#{log_name(script_path)}'"

      cd = cd_command(working_directory)
      qsub_base = qsub_common_command(
        job_name:,
        resources:,
        additional_attributes:,
        env:,
        project_suffix: options.fetch(:project_suffix, nil)
      )

      qsub = "#{qsub_base} #{output} #{hold_string} #{script_path}"
      "#{cd} && #{qsub}"
    end

    def qsub_common_command(job_name:, resources:, additional_attributes:, env:, project_suffix:)
      queue = settings.pbs.default_queue
      # loosely group jobs together without any formal dependencies - they just share a project which is just a tag
      project = project_name(project_suffix)

      # -q <queue_name>
      queue_string = queue.blank? ? '' : "-q #{queue}"

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

      # -j merge stderr and stdout into stdout
      io = '-j oe'

      # mail: don't. At this scale any email is massive spam.
      mail = '-m n'

      # -P <project_name>
      # -N <job_name>
      "#{pbs_bin('qsub')} -N '#{job_name}' -P #{project} #{queue_string} #{io} #{mail} #{resource_string} #{additional_attributes_string} #{env_string}"
    end

    def default_additional_attributes
      {
        'group_list' => settings.pbs.primary_group,
        'umask' => '0002'
      }
    end

    def cd_command(working_directory)
      "cd '#{working_directory}'"
    end

    # @param script_path [Pathname]
    # @return [String]
    def log_name(script_path)
      "#{script_path.basename}.log"
    end

    def pbs_bin(command)
      @bin_path / command
    end

    # Creates a project name from the instance tag and a suffix
    # @param project_suffix [String]
    # @return [String]
    def project_name(project_suffix)
      project_suffix = safe_name(project_suffix)
      instance_tag + (project_suffix.present? ? "_#{project_suffix}" : '')
    end

    # Sanitizes a name, leaving only alphanumeric characters, underscores, and dots.
    # Repeated illegal characters are compacted into a single underscore.
    # Leading and trailing illegal characters are removed.
    # @param name [String]
    # @return [String]
    def safe_name(name)
      name&.to_s&.gsub(SAFE_NAME_REGEX, '_')&.trim('_')
    end

    def split_into_lines(string)
      string&.split(/\r\n|\n/) || []
    end
  end
end
