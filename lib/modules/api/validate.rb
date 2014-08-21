require 'active_support/concern'

# Provides common validations for composing queries.
module Api
  module Validate
    extend ActiveSupport::Concern

    module ClassMethods

      # Validate order by value.
      # @param [Symbol] order_by
      # @param [Array<Symbol>] valid_fields
      # @param [Symbol] direction
      # @raise [ArgumentError] if order_by is not valid
      def validate_order_by(order_by, valid_fields, direction)
        fail ArgumentError, 'Order by must not be null' if order_by.blank?
        fail ArgumentError, "Order by must be in #{valid_fields.inspect}, got #{order_by.inspect}" unless valid_fields.include?(order_by)
        fail ArgumentError, "Direction must be :asc or ;desc, got #{direction.inspect}" unless [:desc, :asc].include?(direction)
      end



    end
  end
end