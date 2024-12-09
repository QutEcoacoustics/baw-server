# frozen_string_literal: true

module FileSystems
  module Structs
    # A top level result for the results API. A description of a directory (
    # and the entries within it) that should be transmitted to the client.
    # that should be transmitted to the client.
    class DirectoryWrapper < Entry
      schema schema.strict

      # @!attribute [r] children
      #   the children of the directory
      #   @return [Entry[]]
      attribute :children, ::BawWorkers::Dry::Types::Array.of(
        Entry
      ).default([].freeze)

      # @!attribute [r] link
      #   the link to another entity that is related to this directory
      #   @return [String, nil]
      attribute? :link, ::BawWorkers::Dry::Types::String.optional

      # @!attribute [r] total_count
      #   the total number of items in the directory
      #   @return [Integer]
      attribute :total_count, ::BawWorkers::Dry::Types::NATURAL.optional.default(0)

      def type
        :directory
      end

      # @!attribute [r] data
      #   additional data to be merged into the result
      #   @return [Hash]
      attribute :data, ::BawWorkers::Dry::Types::Hash.default({}.freeze)

      def to_h
        result = super
        data = result.delete(:data)
        result.merge(data)
      end
    end
  end
end
