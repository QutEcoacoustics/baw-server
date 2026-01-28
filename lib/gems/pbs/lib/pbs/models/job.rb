# frozen_string_literal: true

module PBS
  module Models
    # Represents a jobs on a PBS cluster
    #
    # PBS's JSON output is atrocious. Sometimes numbers are strings (e.g. Exit_status),
    # sometimes numbers aren't even numbers in strings (e.g. timestamp is known to be `^K` sometimes).
    # Almost always fields will be missing if the job is not in a certain state.
    #
    # "0.725ccdf1a5fb": {
    #   "Job_Name": "testname",
    #   "Job_Owner": "pbsuser@725ccdf1a5fb",
    #   "resources_used": { ... },
    #   "job_state": "F",
    #   "queue": "workq",
    #   "server": "725ccdf1a5fb",
    #   "Checkpoint": "u",
    #   "ctime": "Tue Oct 11 08:13:45 2022",
    #   "depend": "beforeany:1014.905bfe60ad67@905bfe60ad67:1015.905bfe60ad67@905bfe60ad67,beforeok:1016.905bfe60ad67@905bfe60ad67",
    #   "Error_Path": "725ccdf1a5fb:/home/pbsuser/testname.e0",
    #   "exec_host": "725ccdf1a5fb/0",
    #   "exec_vnode": "(725ccdf1a5fb:ncpus=1)",
    #   "group_list": "pbsuser",
    #   "Hold_Types": "n",
    #   "Join_Path": "n",
    #   "Keep_Files": "n",
    #   "Mail_Points": "a",
    #   "mtime": "Tue Oct 11 08:13:47 2022",
    #   "Output_Path": "725ccdf1a5fb:/home/pbsuser/testname.o0",
    #   "Priority": 0,
    #   "qtime": "Tue Oct 11 08:13:45 2022",
    #   "Rerunable": "True",
    #   "Resource_List": { ... },
    #   "stime": "Tue Oct 11 08:13:45 2022",
    #   "obittime": "Tue Oct 11 08:13:47 2022",
    #   "jobdir": "/home/pbsuser",
    #   "substate": 92,
    #   "Variable_List": {
    #     "PBS_O_HOME": "/home/pbsuser",
    #     "PBS_O_LANG": "en_US.UTF-8",
    #     "PBS_O_LOGNAME": "pbsuser",
    #     "PBS_O_PATH": "/home/pbsuser/bin:/usr/local/bin:/usr/bin:/bin:/opt/pbs/bin",
    #     "PBS_O_MAIL": "/var/mail/pbsuser",
    #     "PBS_O_SHELL": "/bin/bash",
    #     "PBS_O_WORKDIR": "/home/pbsuser",
    #     "PBS_O_SYSTEM": "Linux",
    #     "PBS_O_QUEUE": "workq",
    #     "PBS_O_HOST": "725ccdf1a5fb"
    #   },
    #   "comment": "Job run at Tue Oct 11 at 08:13 on (725ccdf1a5fb:ncpus=1) and finished",
    #   "etime": "Tue Oct 11 08:13:45 2022",
    #   "run_count": 1,
    #   "Stageout_status": 1,
    #   "Exit_status": 0,
    #   "Submit_arguments": "-N testname -",
    #   "history_timestamp": 1665476027,
    #   "project": "_pbs_project_default",
    #   "Submit_Host": "725ccdf1a5fb"
    #
    #   // more props found on QUT PBS instance
    #   "eligible_time":"00:02:10",
    #   "array":"True",
    #   "array_state_count":"Queued:999 Running:0 Exiting:0 Expired:2 ",
    #   "array_indices_submitted":"0-1000",
    #   "array_indices_remaining":"2-1000",
    #   "estimated":{
    #       "exec_vnode":"(cl4n017[0]:ncpus=8:mem=33554432kb)+(cl4n017[1]:ncpus=4)",
    #       "start_time":"Wed Oct 12 14:48:45 2022"
    #   },
    # }
    class Job < BaseStruct
      # @!attribute [r] job_id
      #   The job id. Note: this attribute is not normally part
      #   of the PBS job status response. It is added by the
      #   by us since moving around a single status object is
      #   easier than moving around a status object and a job id.
      #   @return [String]
      attribute :job_id, ::BawApp::Types::String

      # @!attribute [r] job_name
      #   @return [String]
      attribute :job_name, ::BawApp::Types::String

      # @!attribute [r] job_owner
      #   @return [String]
      attribute :job_owner, ::BawApp::Types::String

      # @!attribute [r] resources_used
      #   @return [String]
      attribute :resources_used, ResourcesUsed.optional.default(nil)

      # @!attribute [r] job_state
      #   @return [String]
      attribute :job_state, ::BawApp::Types::String

      # @!attribute [r] queue
      #   @return [String]
      attribute :queue, ::BawApp::Types::String

      # @!attribute [r] server
      #   @return [String]
      attribute :server, ::BawApp::Types::String

      # @!attribute [r] checkpoint
      #   @return [String]
      attribute :checkpoint, ::BawApp::Types::String

      # @!attribute [r] ctime
      #   @return [Time]
      attribute :ctime, ::BawApp::Types::UtcTime

      # @!attribute [r] depend
      #   @return [Hash<string, Array<string>>]
      attribute? :depend,
        ::BawApp::Types::Hash.map(
          ::BawApp::Types::Symbol,
          ::BawApp::Types::Array.of(::BawApp::Types::String)
        ).optional.default({}.freeze)

      # @!attribute [r] error_path
      #   @return [String]
      attribute :error_path, ::BawApp::Types::String

      # @!attribute [r] exec_host
      #   @return [String]
      attribute? :exec_host, ::BawApp::Types::String

      # @!attribute [r] exec_vnode
      #   @return [String]
      attribute? :exec_vnode, ::BawApp::Types::String

      # @!attribute [r] group_list
      #   @return [String]
      attribute? :group_list, ::BawApp::Types::String

      # @!attribute [r] hold_type
      #   @return [String]
      attribute :hold_types, ::BawApp::Types::String.optional.default(nil)

      # @!attribute [r] join_path
      #   @return [String]
      attribute :join_path, ::BawApp::Types::String

      # @!attribute [r] keep_files
      #   @return [String]
      attribute :keep_files, ::BawApp::Types::String

      # @!attribute [r] mail_points
      #   @return [String]
      attribute :mail_points, ::BawApp::Types::String

      # @!attribute [r] mtime
      #   @return [Time]
      attribute :mtime, ::BawApp::Types::UtcTime

      # @!attribute [r] output_path
      #   @return [String]
      attribute :output_path, ::BawApp::Types::String

      # @!attribute [r] priority
      #   @return [Number]
      attribute :priority, ::BawApp::Types::Params::Integer

      # @!attribute [r] qtime
      #   @return [Time]
      attribute :qtime, ::BawApp::Types::UtcTime

      # @!attribute [r] rerunable
      #   @return [Boolean]
      attribute :rerunable, ::BawApp::Types::Params::Bool

      # @!attribute [r] resource_list
      #   @return [ResourceList,nil]
      attribute :resource_list, ResourceList.optional

      # @!attribute [r] stime
      #   @return [Time,nil]
      attribute? :stime, ::BawApp::Types::UtcTime.optional.default(nil)

      # @!attribute [r] obittime
      #   @return [Time]
      attribute? :obittime, ::BawApp::Types::UtcTime

      # @!attribute [r] job_dir
      #   @return [String]
      attribute? :jobdir, ::BawApp::Types::String

      # @!attribute [r] substate
      #   @return [Time]
      attribute :substate, ::BawApp::Types::Params::Integer

      # @!attribute [r] variable_list
      #   @return [Hash<string,string>]
      attribute :variable_list, ::BawApp::Types::Hash.map(::BawApp::Types::String, ::BawApp::Types::String)

      # @!attribute [r] comment
      #   @return [String]
      attribute? :comment, ::BawApp::Types::String

      # @!attribute [r] etime
      #   @return [Time,nil]
      attribute? :etime, ::BawApp::Types::UtcTime.optional.default(nil)

      # @!attribute [r] run_count
      #   @return [Integer]
      attribute? :run_count, ::BawApp::Types::Params::Integer

      # @!attribute [r] stageout_status
      #   @return [Number]
      attribute? :stageout_status, ::BawApp::Types::Params::Integer

      # @!attribute [r] exit_status
      #   @return [Number]
      attribute? :exit_status, ::BawApp::Types::Params::Integer

      # @!attribute [r] submit_arguments
      #   @return [String]
      attribute :submit_arguments, ::BawApp::Types::String

      # @!attribute [r] history_timestamp
      #   @return [Time]
      attribute? :history_timestamp, ::BawApp::Types::UnixTime

      # @!attribute [r] project
      #   @return [String]
      attribute :project, ::BawApp::Types::String

      # @!attribute [r] submit_host
      #   @return [String]
      attribute :submit_host, ::BawApp::Types::String

      # @!attribute [r] eligible_time
      #   @return [Float]
      attribute? :eligible_time, ::BawApp::Types::Sexagesimal

      # @!attribute [r] array
      #   @return [String]
      attribute? :array, ::BawApp::Types::Params::Bool

      # @!attribute [r] array_state_count
      #   @return [String]
      attribute? :array_state_count, ::BawApp::Types::String

      # @!attribute [r] state
      #   @return [String]
      attribute? :state, ::BawApp::Types::String

      # @!attribute [r] array_indices_submitted
      #   @return [String]
      attribute? :array_indices_submitted, ::BawApp::Types::String

      # @!attribute [r] array_indices_remaining
      #   @return [String]
      attribute? :array_indices_remaining, ::BawApp::Types::String

      # @!attribute [r] estimated
      #   @return [Hash<string,string>]
      attribute? :estimated, ::BawApp::Types::Hash.map(::BawApp::Types::Symbol, ::BawApp::Types::String).optional

      def begun?
        job_state.start_with?('B')
      end

      def exiting?
        job_state.start_with?('E')
      end

      def finished?
        job_state.start_with?('F')
      end

      def held?
        job_state.start_with?('H')
      end

      def moved?
        job_state.start_with?('M')
      end

      def queued?
        job_state.start_with?('Q')
      end

      def running?
        job_state.start_with?('R')
      end

      def suspended?
        job_state.start_with?('S')
      end

      def transitioning?
        job_state.start_with?('T')
      end

      def workstation_busy?
        job_state.start_with?('W')
      end

      def sub_jobs_finished?
        job_state.start_with?('X')
      end
    end
  end
end
