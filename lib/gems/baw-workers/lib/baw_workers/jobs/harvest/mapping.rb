# frozen_string_literal: true

require 'dry/monads'

module BawWorkers
  module Jobs
    module Harvest
      # Represents a mapping between a path on disk
      # and meta information about the files - mainly which site
      # they should be allocated into.
      # This is the next iteration of a harvest.yml file
      class Mapping < ::BawWorkers::Dry::SerializedStrictStruct
        include ::Dry::Monads[:maybe]

        # @!attribute [r] path - a path indicating which paths this mapping
        #   should apply to. Note: the path should have no leading or training slashes.
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
        # @return [Dry::Monads::Maybe<Integer>] Some for success, None for no match.
        #   The contained number is the depth of the match.
        def match(test_path)
          # shortcut return root recursive matching
          return Some(0) if path == '' && recursive

          split_test_path = test_path.split('/', -1)
          split_path = path.split('/', -1)

          # count the number of segments that match
          split_test_path
            .zip(split_path)
            .reduce(0) do |total, (t, p)|
            break total unless t == p

            total + 1
          end => count

          min_length = split_path.length

          # if we haven't matched at least as many path segments as is in this
          # mappings path, then fail
          return None() if count < min_length

          # if any more matches occurred
          # then success, and return the depth of match
          return Some(count) if recursive

          # only return success if all segments matched
          count == split_test_path.size ? Some(count) : None()
        end
      end
    end
  end
end
