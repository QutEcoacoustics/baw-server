# frozen_string_literal: true

module PBS
  module Models
    # Represents a jobs on a PBS cluster
    # {
    #  "timestamp": 1665476097,
    #  "pbs_version": "22.05.11",
    #  "pbs_server": "725ccdf1a5fb",
    #  "Jobs": { ... }
    # }
    class JobList < BaseStruct
      # @!attribute [r] timestamp
      #   @return [Time,nil]
      attribute :timestamp, ::BawApp::Types::UnixTime.optional

      # @!attribute [r] pbs_version
      #   @return [String]
      attribute :pbs_version, ::BawApp::Types::String

      # @!attribute [r] pbs_server
      #   @return [String]
      attribute :pbs_server, ::BawApp::Types::String

      # @!attribute [r] jobs
      #   @return [Hash<String,Job>]
      attribute :jobs, ::BawApp::Types::Hash
        .map(::BawApp::Types::String, ::PBS::Models::Job)
        .default({}.freeze)
    end
  end
end
