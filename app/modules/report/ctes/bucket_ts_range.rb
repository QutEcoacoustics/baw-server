# frozen_string_literal: true

module Report
  module Ctes
    # Generate a series of tsrange values, one for each bucket in a time series
    class BucketTsRange < Report::Cte::Node
      extend Report::TimeSeries
      include Cte::Dsl

      table_name :bucketed_time_series

      depends_on bucket_count: Report::Ctes::BucketCount

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
