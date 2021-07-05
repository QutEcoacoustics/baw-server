# frozen_string_literal: true

module BawWorkers
  module Models
    class AudioRequest < ::BawWorkers::Dry::SerializedStrictStruct
      # @!attribute [r] uuid
      #   @return [String]
      attribute :uuid, ::BawWorkers::Dry::Types::String
      # @!attribute [r] format
      #   @return [String]
      attribute :format, ::BawWorkers::Dry::Types::String
      # @!attribute [r] media_type
      #   @return [String]
      attribute :media_type, ::BawWorkers::Dry::Types::String
      # @!attribute [r] start_offset
      #   @return [String]
      attribute :start_offset, ::BawWorkers::Dry::Types::JSON::Decimal
      # @!attribute [r] end_offset
      #   @return [String]
      attribute :end_offset, ::BawWorkers::Dry::Types::JSON::Decimal
      # @!attribute [r] channel
      #   @return [Integer]
      attribute :channel, ::BawWorkers::Dry::Types::Channel
      # @!attribute [r] sample_rate
      #   @return [Integer]
      attribute :sample_rate, ::BawWorkers::Dry::Types::SampleRate
      # @!attribute [r] datetime_with_offset
      #   @return [TimeWithZone]
      attribute :datetime_with_offset, ::BawWorkers::Dry::Types::JSON::Time
      # @!attribute [r] original_format
      #   @return [String]
      attribute :original_format, ::BawWorkers::Dry::Types::String
      # @!attribute [r] original_sample_rate
      #   @return [Integer]
      attribute :original_sample_rate, ::BawWorkers::Dry::Types::SampleRate
    end
  end
end
