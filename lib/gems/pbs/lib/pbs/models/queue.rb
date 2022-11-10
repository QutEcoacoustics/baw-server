# frozen_string_literal: true

module PBS
  module Models
    # Represents a queue on a PBS cluster
    # The below is an artificial payload constructed fro several queue objects, trying to capture variance
    # "quick":{
    #   "queue_type":"Execution",
    #   "Priority":25,
    #   "total_jobs":7,
    #   "state_count":"Transit:0 Queued:5 Held:0 Waiting:0 Running:2 Exiting:0 Begun:0 ",
    #   "from_route_only":"True",
    #   "resources_max":{
    #       "ngpus":0,
    #       "walltime":"04:00:00"
    #   },
    #   "resources_min":{
    #     "ngpus":1
    #   },
    #   "resources_assigned":{
    #       "mem":"132gb",
    #       "mpiprocs":0,
    #       "ncpus":5,
    #       "nodect":2
    #   },
    #   "max_run":"[o:PBS_ALL=5000]",
    #   "max_run_res":{
    #       "mem":"[u:PBS_GENERIC=40tb]",
    #       "ncpus":"[u:PBS_GENERIC=5000]"
    #   },
    #   "enabled":"True",
    #   "started":"True",
    #   "queued_jobs_threshold":"[u:PBS_GENERIC=5000]"
    # },
    class Queue < BaseStruct
      # @!attribute [r] queue_type
      #   @return [String]
      attribute :queue_type, ::BawApp::Types::String

      # @!attribute [r] priority
      #   @return [Time]
      attribute? :priority, ::BawApp::Types::JSON::Decimal

      # @!attribute [r] total_jobs
      #   @return [Time]
      attribute :total_jobs, ::BawApp::Types::JSON::Decimal

      # @!attribute [r] state_count
      attribute :state_count, ::BawApp::Types::String

      # @!attribute [r] from_route_only
      #   @return [Boolean]
      attribute? :from_route_only, ::BawApp::Types::Params::Bool

      # @!attribute [r] resources_max
      #   @return [Hash<string,(String,Number)>]
      attribute? :resources_max, ::BawApp::Types::Hash.map(::BawApp::Types::String, ::BawApp::Types::JsonScalar)

      # @!attribute [r] resources_min
      #   @return [Hash<string,(String,Number)>]
      attribute? :resources_min, ::BawApp::Types::Hash.map(::BawApp::Types::String, ::BawApp::Types::JsonScalar)

      # @!attribute [r] resources_assigned
      #   @return [Hash<string,(String,Number)>]
      attribute? :resources_assigned, ::BawApp::Types::Hash.map(::BawApp::Types::String, ::BawApp::Types::JsonScalar)

      # @!attribute [r] max_run
      #   @return [String]
      attribute? :max_run, ::BawApp::Types::String

      # @!attribute [r] max_run_res
      #   @return [Hash<string,(String,Number)>]
      attribute? :max_run_res, ::BawApp::Types::Hash.map(::BawApp::Types::String, ::BawApp::Types::JsonScalar)

      # @!attribute [r] enabled
      #   @return [Boolean]
      attribute :enabled, ::BawApp::Types::Params::Bool

      # @!attribute [r] started
      #   @return [Boolean]
      attribute :started, ::BawApp::Types::Params::Bool

      # @!attribute [r] queued_jobs_threshold
      #   @return [String]
      attribute? :queued_jobs_threshold, ::BawApp::Types::String
    end
  end
end
