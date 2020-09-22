# frozen_string_literal: true

module SftpgoClient
  module Validation
    include Dry::Logic
    include Dry::Monads[:result, :do]

    def natural_number?(value)
      return Failure("#{value} was not a integer") unless value.is_a?(Integer)
      return Failure("#{value} was not >= 0") unless value >= 0

      Success(value)
    end

    def string?(value)
      return Failure("#{value} was not a string") unless value.is_a?(String)

      Success(value)
    end

    def validate_id(name, value)
      return if value.is_a?(Integer) && value >= 0

      raise ArgumentError "#{name} must be an integer and not negative"
    end

    def add_to_params(hash, name, value, &validation)
      return if value.nil?

      validated_value = validation.nil? ? Success(value) : validation.call(value)
      raise ArgumentError, "#{name} was not valid: #{valid.failure}" unless validated_value.success?

      hash[:name] = validated_value.value!
    end
  end
end
