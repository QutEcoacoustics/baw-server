# frozen_string_literal: true

module BawWorkers
  module Models


    class SpectrogramRequest < AudioRequest
      # @!attribute [r] window
      #   @return [Integer]
      attribute :window, ::BawWorkers::Dry::Types::Window
      # @!attribute [r] window_function
      #   @return [String]
      attribute :window_function, ::BawWorkers::Dry::Types::String
      # @!attribute [r] colour
      #   @return [String]
      attribute :colour, ::BawWorkers::Dry::Types::String
    end
  end
end
