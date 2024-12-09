# frozen_string_literal: true

module FileSystems
  module Structs
    # A top level result for the results API. A description of a File
    # that should be transmitted to the client.
    class FileWrapper < File
      # @!attribute [r] io
      #   the io of the file
      #   @return [IO]
      attribute :io, ::BawWorkers::Dry::Types::Any

      # @!attribute [r] modified
      #   the last modified time of the file
      #   @return [Time]
      attribute :modified, ::BawWorkers::Dry::Types::Time
    end
  end
end
