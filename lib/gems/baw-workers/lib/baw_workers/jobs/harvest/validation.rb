# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # A validation for a file that we're going to harvest
      # !@abstract
      class Validation
        include Singleton

        def validate(_harvest_item)
          raise NotImplementedError('abstract method needs implementation')
        end

        def self.code(new_code = nil)
          @code = new_code if new_code.present?

          return @code if defined?(@code)

          raise NotImplementedError('abstract method needs implementation')
        end

        protected

        def fixable(message)
          code = self.class.code
          ValidationResult.new(code:, status: ValidationResult::STATUS_FIXABLE, message:)
        end

        def not_fixable(message)
          code = self.class.code
          ValidationResult.new(code:, status: ValidationResult::STATUS_NOT_FIXABLE, message:)
        end
      end
    end
  end
end
