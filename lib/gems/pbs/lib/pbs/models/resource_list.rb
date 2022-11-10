# frozen_string_literal: true

module PBS
  module Models
    # Represents a jobs on a PBS cluster
    #   "Resource_List": {
    #     "ncpus": 1,
    #     "nodect": 1,
    #     "place": "pack",
    #     "select": "1:ncpus=1"
    #   },
    class ResourceList < BaseStruct
      # @!attribute [r] ncpus
      #   @return [String]
      attribute? :ncpus, ::BawApp::Types::JSON::Decimal

      # @!attribute [r] walltime
      #   @return [String]
      attribute? :walltime, ::BawApp::Types::String

      # @!attribute [r] mem
      #   @return [String]
      attribute? :mem, ::BawApp::Types::String

      # @!attribute [r] nodect
      #   @return [String]
      attribute? :nodect, ::BawApp::Types::JSON::Decimal

      # @!attribute [r] place
      #   @return [String]
      attribute? :place, ::BawApp::Types::String

      # @!attribute [r] select
      #   @return [String]
      attribute? :select, ::BawApp::Types::String
    end
  end
end
