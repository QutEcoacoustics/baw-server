# frozen_string_literal: true

module FileSystems
  module Structs
    # A data class that represents a file or directory in a virtual results file system.
    class Entry < ::Dry::Struct
      # @!attribute [r] path
      #   The route (URL path) to the file or directory, relative to the root of the web server
      #   Rarely, there can be multiple names for a single file or directory.
      #   @return [String,Array<String>]
      attribute :path,
        ::BawWorkers::Dry::Types::String |
        ::BawWorkers::Dry::Types::Array.of(::BawWorkers::Dry::Types::String)

      # @!attribute [r] name
      #   The name of the file or directory
      #   Rarely, there can be multiple names for a single file or directory.
      #   @return [String,Array<string>]
      attribute :name,
        ::BawWorkers::Dry::Types::String |
        ::BawWorkers::Dry::Types::Array.of(::BawWorkers::Dry::Types::String)

      # @!attribute [r] virtual_item_ids
      #   the objects from the database that were used to generate this result
      #   @return [Array<Integer>]
      attribute :virtual_item_ids,
        ::BawWorkers::Dry::Types::Array.of(::BawWorkers::Dry::Types::Integer).default([].freeze)

      # @!attribute [r] physical_paths
      #   the paths on the file system that were used to generate this result
      #   @return [Array<Pathname>]
      attribute :physical_paths,
        ::BawWorkers::Dry::Types::Array.of(::BawWorkers::Dry::Types::Pathname).default([].freeze)

      # @!attribute [r] type
      #   the type of the file or directory
      #   @return [Symbol]
      def type
        raise NotImplementedError
      end

      def directory?
        type == :directory || type == :both
      end

      def file?
        type == :file || type == :both
      end

      def to_h
        super.except(:virtual_item_ids, :physical_paths)
      end
    end
  end
end
