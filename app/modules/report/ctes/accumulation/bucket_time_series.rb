# frozen_string_literal: true

module Report
  module Ctes
    module Accumulation
      # Defines a CTE that generates a series of time buckets for a given time range
      # and count of buckets.
      #
      # == query output
      #
      #  emits columns:
      #    bucket_number (int) -- sequential bucket index, 1-based
      #    time_bucket   (tsrange) -- the time range for this bucket, [inclusive start, exclusive end)
      #
      #  emits rows: one per bucket, from 1 to bucket_count
      class BucketTimeSeries < Cte::NodeTemplate
        extend Report::TimeSeries

        table_name :bucket_time_series

        dependencies bucket_count: BucketCount

        select do
          series = generate_series(bucket_count[:bucket_count].ceil).to_sql
          series_alias = Arel.sql('bucket_number')

          # ! magic string bucket_interval
          range_from = Arel.sql('lower(time_range) + ((? - 1) * bucket_interval)', series_alias)
          range_to = Arel.sql('lower(time_range) + (? * bucket_interval)', series_alias)
          ts_range = Arel.sql('tsrange(?, ?)', range_from, range_to).as('time_bucket')

          bucket_count
            .project(series_alias, ts_range)
            .join(Arel.sql("CROSS JOIN #{series} AS #{series_alias}"))
        end
      end
    end
  end
end
