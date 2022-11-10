# frozen_string_literal: true

module PBS
  module Models
    # Represents a jobs on a PBS cluster
    #   "resources_used": {
    #     "cpupercent": 0,
    #     "cput": "00:00:00",
    #     "mem": "0kb",
    #     "ncpus": 1,
    #     "vmem": "0kb",
    #     "walltime": "00:00:01"
    #   },
    class ResourcesUsed < BaseStruct
      # @!attribute [r] cpupercent
      #   @return [Time]
      attribute :cpupercent, ::BawApp::Types::JSON::Decimal

      # @!attribute [r] cput
      #   @return [String]
      attribute :cput, ::BawApp::Types::String

      # @!attribute [r] mem
      #   @return [String]
      attribute :mem, ::BawApp::Types::String

      # @!attribute [r] ncpus
      #   @return [String]
      attribute :ncpus, ::BawApp::Types::JSON::Decimal

      # @!attribute [r] vmem
      #   @return [String]
      attribute :vmem, ::BawApp::Types::String

      # @!attribute [r] walltime
      #   @return [String]
      attribute :walltime, ::BawApp::Types::String
    end
  end
end
