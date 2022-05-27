# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Represents the semi-structured json info kept on a harvest_item record
      class Info < ::BawWorkers::Dry::SerializedStrictStruct
        # @!attribute [r] error
        #   @return [String]
        attribute :error, ::BawWorkers::Dry::Types::String.optional.default(nil)

        # @!attribute [r] fixes
        #   @return [Array<Hash>]
        attribute :fixes, ::BawWorkers::Dry::Types::Array
          .of(::BawWorkers::Dry::Types::Hash)
          .default([].freeze)

        # @!attribute [r] file_info
        #   @return [Hash]
        attribute :file_info, ::BawWorkers::Dry::Types::DeeplySymbolizedHash
          .default(->(_type) { {}.freeze }.freeze)

        # @!attribute [r] validations
        #   @return [Array<Hash>]
        attribute :validations, ::BawWorkers::Dry::Types::Array
          .of(::BawWorkers::Jobs::Harvest::ValidationResult)
          .default([].freeze)
      end
    end
  end
end
