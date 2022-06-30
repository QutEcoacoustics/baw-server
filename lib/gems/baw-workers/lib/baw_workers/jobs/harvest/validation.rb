# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # A validation for a file that we're going to harvest
      # !@abstract
      class Validation
        include Singleton

        # rubocop:disable Lint/UnusedMethodArgument
        # @abstract
        # @param harvest_item [HarvestItem]
        def validate(harvest_item)
          raise NotImplementedError('abstract method needs implementation')
        end
        # rubocop:enable Lint/UnusedMethodArgument

        def self.validation_name(new_name = nil)
          @validation_name = new_name if new_name.present?

          return @validation_name if defined?(@validation_name)

          raise NotImplementedError('abstract method needs implementation')
        end

        protected

        def fixable(message)
          name = self.class.validation_name
          ValidationResult.new(name:, status: ValidationResult::STATUS_FIXABLE, message:)
        end

        def not_fixable(message)
          name = self.class.validation_name
          ValidationResult.new(name:, status: ValidationResult::STATUS_NOT_FIXABLE, message:)
        end
      end
    end
  end
end
