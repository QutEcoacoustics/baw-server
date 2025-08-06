# frozen_string_literal: true

module Report
  module Ctes
    # This is the root CTE for the tag accumulation aggregated result
    class AggTagAccumulation < Report::Cte::Node
      include Cte::Dsl

      table_name :tag_accumulation

      depends_on bucket_cumulative_unique: Report::Ctes::BucketCumulativeUnique

      select do
        cumulative_table_aliased = bucket_cumulative_unique.as('t')
        Arel::SelectManager.new
          .project(cumulative_table_aliased.right.row_to_json.json_agg.as('accumulation_series'))
          .from(cumulative_table_aliased)
      end
    end
  end
end
