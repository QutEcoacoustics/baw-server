# frozen_string_literal: true

module Api
  module Reporting
    # Mixin providing helpers for formatting report results
    module ResultFormatters
      # Ensure the resulting hash contains only `keys`, sourced from `row`.
      #
      # Missing keys are initialized to `nil`.
      #
      # @param keys [Array<Symbol | String>]
      # @param row [Hash]
      # @return [Hash]
      def ensure_columns(keys, row)
        keys.index_with { |key| row.fetch(key, nil) }
      end

      # Extract histogram data from `summary` and format it under the specified key; set key to nil if histogram data absent.
      # @param summary [Hash]
      # @param histogram_key [Symbol | String]
      # @return [Hash]
      def extract_histogram(summary, histogram_key:)
        summary = summary ? summary.symbolize_keys : {}

        other_keys = summary.except(:histogram_bins, :histogram_minimum, :histogram_maximum)
        other_keys[histogram_key] =
          if summary[:histogram_bins]
            {
              bins: summary[:histogram_bins][1...-1],
              maximum: summary[:histogram_maximum],
              minimum: summary[:histogram_minimum],
              underflow: summary[:histogram_bins].first,
              overflow: summary[:histogram_bins].last
            }
          else
            nil
          end

        other_keys
      end
    end
  end
end
