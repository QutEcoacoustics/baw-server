# frozen_string_literal: true

module Report
  module Ctes
    # This is the root CTE for the tag accumulation aggregated result
    # @see Report::Ctes::BucketCumulativeUnique
    class AggTagAccumulation < Report::Cte::NodeTemplate

      table_name :tag_accumulation

      depdendencies bucket_cumulative_unique: Report::Ctes::BucketCumulativeUnique

      select do
        cumulative_table_aliased = bucket_cumulative_unique.as('t')
        Arel::SelectManager.new
          .project(cumulative_table_aliased.right.row_to_json.json_agg.as('accumulation_series'))
          .from(cumulative_table_aliased)
      end

      def self.format_result(result, base_key = 'accumulation_series', suffix: nil)
        key = suffix ? "#{base_key}_#{suffix}" : base_key
        Decode.row_with_tsrange result, key
      end
    end
  end
end
