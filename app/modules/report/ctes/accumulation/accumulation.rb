# frozen_string_literal: true

module Report
  module Ctes
    #
    # The Accumulation module provides a namespace for CTE templates used for
    # calculating an accumulation curve.
    #
    # This includes more generic CTEs that can be reused in other contexts.
    #   For example, {TimeRangeAndInterval} projects basic time series
    #   configuration values, and {BucketTimeSeries} generates a series of time
    #   buckets.
    module Accumulation
      #
      # Root CTE template for an accumulation time series result
      #
      # Defines a CTE that formats the results of {BucketCumulativeUnique} into
      # a JSON array representing the accumulation series. This is used in the
      # {AudioEventSummary} report.
      #
      # == query output
      #
      #  emits column:
      #    accumulation_series (json) -- an array of bucket objects
      #
      #  emits json fields in accumulation_series[*]:
      #    bucket_number (int) -- sequential bucket index, 1-based
      #    range (string)      -- tsrange literal in canonical form, inclusive start, exclusive end
      #    count (int)         -- cumulative total up to and including this bucket
      #
      # @todo add output field accumulation_series[*].error
      #
      # @example Basic usage
      #   result = Report::Ctes::Accumulation::Accumulation.execute
      #   series = Report::Ctes::Accumulation::Accumulation.format_result(result.first)
      class Accumulation < Cte::NodeTemplate
        table_name :tag_accumulation

        dependencies bucket_cumulative_unique: BucketCumulativeUnique

        select do
          cumulative_table_aliased = bucket_cumulative_unique.as('t')
          Arel::SelectManager.new
            .project(cumulative_table_aliased.right.row_to_json.json_agg.as('accumulation_series'))
            .from(cumulative_table_aliased)
        end

        # @param [Hash{String=>String}] result the result hash from executing the query
        # @param [String] base_key to access the result string, default 'accumulation_series'
        # @return [Array<Hash>] array of result tuples (as hashes)
        # @example Basic usage
        #   result_hash = Accumulation.new().execute.first
        #   Accumulation.format_result(result_hash)
        def self.format_result(result, base_key = 'accumulation_series', suffix: nil)
          key = suffix ? "#{base_key}_#{suffix}" : base_key
          Decode.row_with_tsrange result, key
        end
      end
    end
  end
end
