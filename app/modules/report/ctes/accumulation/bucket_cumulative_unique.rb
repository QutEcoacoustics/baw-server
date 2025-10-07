# frozen_string_literal: true

module Report
  module Ctes
    module Accumulation
      # Defines a CTE that generates a complete bucket series, with a cumulative
      # count of unique tags seen up to and including each bucket.
      #
      # Counts of new unique tags per bucket are provided by the
      # {BucketSumUnique} CTE. The full series of buckets is provided by the
      # {BucketTimeSeries} CTE. An outer join is used to so all buckets are
      # output in the result. A running total of unique tags is calculated with
      # a window funtion, across the ordered set of buckets.
      #
      # == query output
      #
      #  emits columns:
      #    bucket_number (numeric) -- sequential bucket index, 1-based
      #    range (tsrange)         -- the time range for this bucket, [inclusive start, exclusive end)
      #    count (int)             -- cumulative total up to and including this bucket
      #
      # emits rows: one per bucket, from 1 to total bucket count
      class BucketCumulativeUnique < Cte::NodeTemplate
        table_name :bucket_cumulative_unique

        dependencies bucket_time_series: BucketTimeSeries, sum_unique: BucketSumUnique

        select do
          window = Arel::Nodes::Window.new.order(bucket_time_series[:bucket_number])
          sum_unique_tags_over_window = sum_unique[:sum_new_tags].sum.over(window)
          bucket_time_series.project(
            bucket_time_series[:bucket_number],
            bucket_time_series[:range],
            sum_unique_tags_over_window.coalesce(0).cast('int').as('count')
          )
            .join(sum_unique, Arel::Nodes::OuterJoin)
            .on(bucket_time_series[:bucket_number].eq(sum_unique[:bucket]))
            .order(bucket_time_series[:bucket_number].asc)
        end
      end
    end
  end
end
