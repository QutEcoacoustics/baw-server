# frozen_string_literal: true

module BawWeb
  module ActiveModel
    # Having trouble tracking down which field is causing a RangeError in production.
    # This patch will include the attribute name in the error message.
    module Attribute
      def value_for_database
        super
      rescue ::ActiveModel::RangeError => e
        raise ::ActiveModel::RangeError, "#{e.message} for attribute: #{name}.", cause: e
      end
    end
  end
end

puts 'PATCH: BawWeb::ActiveModel::Attribute applied to ActiveModel::Attribute'
ActiveModel::Attribute.prepend BawWeb::ActiveModel::Attribute
