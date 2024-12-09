# frozen_string_literal: true

module FileSystems
  module Structs
    # A child result for the results API. A representation of a file that is
    # both a file and a directory. E.g. zip files can be downloaded, or
    # inspected like a directory
    class DirectoryFile < Entry
      # @!attribute [r] size
      #   the size of the file
      #   @return [Integer]
      attribute :size, ::BawWorkers::Dry::Types::NATURAL

      # @!attribute [r] mime
      #   the mime type of the file
      #   @return [String]
      attribute :mime, ::BawWorkers::Dry::Types::String.default('application/octet-stream')

      # @!attribute [r] has_children
      #   Whether the directory has children.
      #   `nil` represents unknown.
      #   @return [Boolean]
      attribute :has_children, ::BawWorkers::Dry::Types::Bool.default(false)

      def type
        :both
      end
    end
  end
end
