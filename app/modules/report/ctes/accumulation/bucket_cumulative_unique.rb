# frozen_string_literal: true

module Report
  module Ctes
    module Accumulation
      class BucketCumulativeUnique < Cte::NodeTemplate
        table_name :bucket_cumulative_unique

        dependencies bucket_time_series: BucketTimeSeries, sum_unique: BucketSumUnique

        select do
          window = Arel::Nodes::Window.new.order(bucket_time_series[:bucket_number])
          sum_unique_tags_over_window = sum_unique[:sum_new_tags].sum.over(window)
          bucket_time_series.project(
            bucket_time_series[:bucket_number],
            bucket_time_series[:time_bucket].as('range'),
            sum_unique_tags_over_window.coalesce(0).cast('int').as('count')
          )
            # outer join the sums with the full bucket time series to get all
            # bins as data points
            .join(sum_unique, Arel::Nodes::OuterJoin)
            .on(bucket_time_series[:bucket_number].eq(sum_unique[:bucket]))
            .order(bucket_time_series[:bucket_number].asc)
        end
      end
    end
  end
end
