# frozen_string_literal: true

module FileSystems
  module Structs
    # A child result for the results API. A description of a file that is a child
    # of the current directory.
    class File < Entry
      # @!attribute [r] size
      #   the size of the file
      #   @return [Integer]
      attribute :size, ::BawWorkers::Dry::Types::NATURAL

      # @!attribute [r] mime
      #   the mime type of the file
      #   @return [String]
      attribute :mime, ::BawWorkers::Dry::Types::String.default('application/octet-stream')

      def type
        :file
      end
    end
  end
end
