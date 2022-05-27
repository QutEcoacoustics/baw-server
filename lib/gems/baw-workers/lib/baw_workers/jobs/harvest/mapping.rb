# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Represents a mapping between a path on disk
      # and meta information about the files - mainly which site
      # they should be allocated into.
      # This is the next iteration of a harvest.yml file
      class Mapping < ::BawWorkers::Dry::SerializedStrictStruct
        # @!attribute [r] path
        #   @return [String]
        attribute :path, ::BawWorkers::Dry::Types::TrimmedDirectoryString

        # @!attribute [r] site_id
        #   @return [Integer]
        attribute :site_id, ::BawWorkers::Dry::Types::ID.optional

        # @!attribute [r] utc_offset
        #   @return [String,nil]
        attribute :utc_offset, ::BawWorkers::Dry::Types::UtcOffsetString.optional

        # @!attribute [r] recursive
        #   @return [Boolean]
        attribute :recursive, ::BawWorkers::Dry::Types::Bool

        # Tests whether a path matches this mapping or not
        # @param test_path [String] a path like string that is not prefixed with a '/'
        # @return [Boolean]
        def match(test_path)
          recursive ? test_path.start_with?(path) : test_path == path
        end
      end
    end
  end
end
