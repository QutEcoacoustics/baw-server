# frozen_string_literal: true

require 'dry/struct'

module Emu
  # The result from running Emu
  class ExecuteResult < ::Dry::Struct
    module Types
      include Dry.Types()
    end

    schema schema.strict

    # @!attribute [r] success
    #   @return [String]
    attribute :success, Types::Strict::Bool

    # @!attribute [r] records
    #   @return [Array<Hash>]
    attribute :records, Types::Array.of(Types::Nominal::Hash)

    # @!attribute [r] log
    #   @return [String]
    attribute :log, Types::Strict::String

    # @!attribute [r] time_taken
    #   @return [Float]
    attribute :time_taken, Types::Coercible::Float

    def success?
      success == true
    end
  end
end
