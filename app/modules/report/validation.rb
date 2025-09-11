# frozen_string_literal: true

module Report
  module Validation
    def self.included(base)
      base.extend ClassMethods
      base.instance_variable_set(:@_validation_contract, nil)
    end

    module ClassMethods
      def validate_with(contract)
        @_validation_contract = contract.new
      end

      def contract_registered_for_my_class
        @_validation_contract
      end
    end

    def validate_options(opts)
      contract = self.class.contract_registered_for_my_class
      return unless contract

      result = contract.call(opts)

      return result.to_h if result.success?

      error_messages = result.errors(full: true).map(&:text).join(', ')
      raise ArgumentError, "invalid options for #{self.class.name}: #{error_messages}"
    end
  end
end
