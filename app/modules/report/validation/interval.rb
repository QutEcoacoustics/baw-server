# frozen_string_literal: true

require 'dry-validation'

module Report
  module Validation
    class Interval < Dry::Validation::Contract
      params do
        required(:interval).filled(:string)
      end

      supported_intervals = ['day', 'week', 'month', 'year']

      rule(:interval) do
        key.failure('has invalid format') unless /[0-9]\s\b(#{supported_intervals.join('|')})\b/.match?(value)
      end
    end
  end
end
