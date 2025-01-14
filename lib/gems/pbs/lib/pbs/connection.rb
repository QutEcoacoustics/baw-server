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

    ENV_PBS_O_WORKDIR = 'PBS_O_WORKDIR'
    ENV_PBS_O_QUEUE = 'PBS_O_QUEUE'
    ENV_PBS_JOBNAME = 'PBS_JOBNAME'
    ENV_PBS_JOBID = 'PBS_JOBID'
    ENV_TMPDIR = 'TMPDIR'

    JOB_ID_REGEX = /(\d+)(\.[-\w]+)?/

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
    end

    # Fetches all statuses for the connection user.
    # @return [::Dry::Monads::Result<::PBS::Models::JobList>]
    def fetch_all_statuses(skip: nil, take: 25)
      raise ArgumentError, '`skip` must be positive Integer' unless skip.nil? || (skip.is_a?(Integer) && skip.positive?)
      raise ArgumentError, '`take` must be positive Integer' unless take.nil? || (take.is_a?(Integer) && take.positive?)

      username = settings.connection.username
      qselect = "qselect -x -u #{username}"
      skip = skip.present? ?  " | tail -n +#{skip + 1}" : ''
      take = take.present? ?  " | head -n #{take}" : ''
      filter = qselect + skip + take
      command = "qstat -x -f -F JSON $(#{filter})"

      execute_safe(command).fmap { |stdout, _stderr|
        parse_status_payload(stdout)
      }
    end

    # Fetch a single status.
    # If more than one job matches the search criteria, the first is returned.
    # @param job_id_or_name [String] can contain job_ids or job_names,
    # @return [::Dry::Monads::Result<::PBS::Models::Job>] a tuple of the job_id and job
    def fetch_status(job_id_or_name)
      raise ArgumentError, 'job_id_or_name must be a String' unless job_id_or_name.is_a?(String)

      command = "qstat -x -f -F JSON #{job_id_or_name}"

      execute_safe(command).fmap { |stdout, _stderr|
        job_list = parse_status_payload(stdout)
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
      command = 'qstat -Q -f -F JSON'

      execute_safe(command).fmap { |stdout, _stderr|
        queue_transformer.call(stdout)
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
    #
    # @param script [String] a bash script to execute in the body of the wrapper script
    # @param working_directory [Pathname] where to store the script and the results.
    #   This path will get translated from a local path to a remote path
    # @param options [Hash] job_name, hook points, resource list, & env vars for the job
    # @option options [String] :job_name a name for the job - should not include an extension
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
      options
        .fetch(:job_name, now.strftime('job_%Y%m%dT%H%M%S%z'))
        .gsub(/[^_A-Za-z0-9.]+/, '_') => name

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
        working_directory:,
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
        .bind { |_| execute_safe(command, fail_message: 'submitting job with qsub') }
        # return job status
        .fmap { |stdout, _stderr| stdout.strip }
    end

    # Deletes a job identified by a job id
    # @param job_id [String] the job id
    # @param wait [Boolean] whether to wait for the job to be finish
    # @param completed [Boolean] whether to delete the job from the completed queue
    # @param force [Boolean] whether to force the job to be deleted
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def cancel_job(job_id, wait: false, completed: false, force: false)
      options = completed ? '-x' : ''
      options += ' -W force' if force
      command = "qdel #{options} #{job_id}"

      command += " && while qstat '#{job_id}' &> /dev/null; do echo 'waiting' ; sleep 0.5; done" if wait

      execute_safe(command, fail_message: "deleting job #{job_id}")
    end

    # Releases a job identified by a job id
    # @param job_id [String] the job id
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def release_job(job_id)
      command = "qrls #{job_id}"

      execute_safe(command, fail_message: "releasing job #{job_id}")
    end

    # Deletes all jobs created by the connection user
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def clean_all_jobs
      # select jobs, including historical, by user which we're connecting with
      # then delete each, including historical
      command = "qselect -x -u #{settings.connection.username} | xargs --no-run-if-empty qdel -x -W force"

      execute_safe(command, fail_message: 'cleaning all jobs')
    end

    # Gets the number of jobs currently enqueued - no matter the state.
    # Even finished jobs are counted against user limits
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_enqueued_count
      command = "qselect -u #{settings.connection.username} | wc -l"

      execute_safe(command).fmap { |stdout, _stderr|
        stdout&.strip.to_i
      }
    end

    # Gets the number of jobs currently in the queued states
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_queued_count
      command = "qselect -s Q -u #{settings.connection.username} | wc -l"

      execute_safe(command).fmap { |stdout, _stderr|
        stdout&.strip.to_i
      }
    end

    # Gets the number of jobs currently running for the connection user
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_running_count
      command = "qselect -s R -u #{settings.connection.username} | wc -l"

      execute_safe(command).fmap { |stdout, _stderr|
        stdout&.strip.to_i
      }
    end

    # Gets max_queued from qmgr.
    # Returns an integer where 0 represents an unset value.
    # @return [::Dry::Monads::Result<Integer>]
    def fetch_max_queued
      # https://help.altair.com/2022.1.0/PBS%20Professional/PBSReferenceGuide2022.1.pdf page #368
      # the `u:PBS_GENERIC` is a limit for generic users
      # TODO: do I need to cater for different sorts of limits?
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
        instance_tag:
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
        env:
      )

      qsub = "#{qsub_base} #{output} #{hold_string} #{script_path}"
      "#{cd} && #{qsub}"
    end

    def qsub_common_command(job_name:, resources:, additional_attributes:, env:)
      queue = settings.pbs.default_queue
      project = settings.pbs.default_project

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
      "qsub -N '#{job_name}' -P #{project} #{queue_string} #{io} #{mail} #{resource_string} #{additional_attributes_string} #{env_string}"
    end

    def default_additional_attributes
      {
        'group_list' => settings.pbs.primary_group
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

    def split_into_lines(string)
      string.split(/\r\n|\n/)
    end
  end
end