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
      #   @return [Time,nil]
      attribute :cpupercent, ::BawApp::Types::Coercible::Float.optional.default(nil)

      # @!attribute [r] cput
      #   @return [Float]
      attribute :cput, ::BawApp::Types::Sexagesimal.optional.default(nil)

      # @!attribute [r] mem
      #   @return [Integer]
      attribute :mem, ::BawApp::Types::PbsByteFormat.optional.default(nil)

      # @!attribute [r] ncpus
      #   @return [String]
      attribute :ncpus, ::BawApp::Types::Strict::Integer.optional.default(nil)

      # @!attribute [r] vmem
      #   @return [Integer]
      attribute :vmem, ::BawApp::Types::PbsByteFormat.optional.default(nil)

      # @!attribute [r] walltime
      #   @return [Float]
      attribute :walltime, ::BawApp::Types::Sexagesimal.optional.default(nil)
    end
  end
end
