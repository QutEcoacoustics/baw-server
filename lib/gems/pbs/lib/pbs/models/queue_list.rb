# frozen_string_literal: true

module PBS
  module Models
    # Represents a jobs on a PBS cluster
    #{
    #  "timestamp":1666251726,
    #  "pbs_version":"2021.1.3.20220217134230",
    #  "pbs_server":"pbs-primary",
    #  "Queue": { ... }
    #}
    class QueueList < BaseStruct
      # @!attribute [r] timestamp
      #   @return [Time,nil]
      attribute :timestamp, ::BawApp::Types::UnixTime.optional

      # @!attribute [r] pbs_version
      #   @return [String]
      attribute :pbs_version, ::BawApp::Types::String

      # @!attribute [r] pbs_server
      #   @return [String]
      attribute :pbs_server, ::BawApp::Types::String

      # @!attribute [r] queue
      #   @return [Hash<String,Queue>]
      attribute :queue, ::BawApp::Types::Hash
        .map(::BawApp::Types::String, ::PBS::Models::Queue)
        .default({}.freeze)
    end
  end
end
