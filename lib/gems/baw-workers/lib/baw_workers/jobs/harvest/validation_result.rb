# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Represents the a validation for a harest item
      class ValidationResult < ::BawWorkers::Dry::SerializedStrictStruct
        STATUS_FIXABLE = 'fixable'
        STATUS_AUTO_FIXABLE = 'auto_fixable'
        STATUS_NOT_FIXABLE = 'not_fixable'

        # @!attribute [r] code
        #   @return [Symbol]
        attribute :code, ::BawWorkers::Dry::Types::Coercible::Symbol

        # @!attribute [r] status
        #   @return [String]
        attribute :status, ::BawWorkers::Dry::Types::String.enum(
          BawWorkers::Jobs::Harvest::ValidationResult::STATUS_FIXABLE,
          BawWorkers::Jobs::Harvest::ValidationResult::STATUS_NOT_FIXABLE
        )

        # @!attribute [r] messaage
        #   @return [String]
        attribute :message, ::BawWorkers::Dry::Types::String.optional
      end
    end
  end
end
