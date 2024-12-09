# frozen_string_literal: true

module FileSystems
  module Structs
    # A child result for the results API. A description of a directory that is a
    # child of the current directory.
    class Directory < Entry
      # @!attribute [r] has_children
      #   Whether the directory has children.
      #   `nil` represents unknown.
      #   @return [Boolean]
      attribute :has_children, ::BawWorkers::Dry::Types::Bool.default(false)

      # @!attribute [r] link
      #   the link to another entity that is related to this directory
      #   @return [String, nil]
      attribute? :link, ::BawWorkers::Dry::Types::String.optional

      def type
        :directory
      end
    end
  end
end
