# frozen_string_literal: true

# PostgreSQL timestamps retain microseconds; in-memory timestamps can retain nanoseconds.
RSpec::Matchers.define :match_attributes do |attributes, options = {}|
  time_tolerance = options.fetch(:time_tolerance, 0.000001)

  match do |actual|
    actual.is_a?(Hash) && actual.size == attributes.size && attributes.all? do |key, expected_value|
      next false unless actual.key?(key)

      actual_value = actual[key]
      if expected_value.acts_like?(:time)
        actual_value.acts_like?(:time) &&
          (actual_value.to_time - expected_value.to_time).abs <= time_tolerance
      else
        actual_value == expected_value
      end
    end
  end

  description do
    "match attributes with timestamps within #{time_tolerance} seconds"
  end

  diffable
end
