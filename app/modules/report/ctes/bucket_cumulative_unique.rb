# frozen_string_literal: true

module Report
  module Ctes
    class BucketCumulativeUnique < Report::Cte::Node
      include Cte::Dsl

      table_name :bucket_cumulative_unique

      depends_on bucket_ts: Report::Ctes::BucketTsRange, sum_unique: Report::Ctes::BucketSumUnique

      select do
        window = Arel::Nodes::Window.new.order(bucket_ts[:bucket_number])
        sum_unique_tags_over_window = sum_unique[:sum_new_tags].sum.over(window)
        bucket_ts.project(
          bucket_ts[:bucket_number],
          bucket_ts[:time_bucket].as('range'),
          sum_unique_tags_over_window.coalesce(0).cast('int').as('count')
        )
          # outer join the sums with the full bucket time series to get all
          # bins as data points
          .join(sum_unique, Arel::Nodes::OuterJoin)
          .on(bucket_ts[:bucket_number].eq(sum_unique[:bucket]))
          .order(bucket_ts[:bucket_number].asc)
      end
    end
  end
end
