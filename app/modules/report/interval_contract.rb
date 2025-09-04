# frozen_string_literal: true

require 'dry-validation'

# wrap node object creation with a validation layer for options

module Report
  class IntervalContract < Dry::Validation::Contract
    params do
      required(:interval).filled(:string)
    end

    intervals = ['day', 'week', 'month', 'year']

    rule(:interval) do
      key.failure('has invalid format') unless /[0-9]\s\b(#{intervals.join('|')})\b/.match?(value)
    end
  end
end
