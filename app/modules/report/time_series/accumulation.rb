# frozen_string_literal: true

module Report
  module TimeSeries
    module Accumulation
      module_function

      include Report::ArelHelpers

      def accumulation_series_result(base_table, parameters)
        accumulation_series_ctes = []

        time_series_config = TimeSeries::StartEndTime.call(parameters)

        # set up the time series config values as a cte
        time_range_and_interval = TimeSeries.time_range_and_interval_query(time_series_config)
        accumulation_series_ctes << time_range_and_interval.cte

        # calculate the minimum number of buckets needed to cover the time range
        number_of_buckets = TimeSeries.number_of_buckets_query(time_range_and_interval,
          time_series_config[:interval])
        accumulation_series_ctes << number_of_buckets.cte

        # generate a series of tsrange values, one for each bucket
        bucketed_time_series = TimeSeries.bucketed_time_series_query(number_of_buckets)
        accumulation_series_ctes << bucketed_time_series.cte

        # from the base data table, select each row's tag_id value, and the bucket
        # number that the row falls into
        data_with_allocated_bucket = TimeSeries.allocate_bucket_based_on_start_time_abosolute(
          base_table,
          number_of_buckets
        )
        accumulation_series_ctes << data_with_allocated_bucket.cte

        # same shape as data_with_allocated_bucket, plus an additional column,
        # that marks a row with 1 when the tag is first seen in the bucket order
        tag_first_appearance = TimeSeries.tag_first_appearance_query(data_with_allocated_bucket)
        accumulation_series_ctes << tag_first_appearance.cte

        sum_unique_tags_by_bucket = TimeSeries.sum_unique_tags_by_bucket_query(tag_first_appearance)
        accumulation_series_ctes << sum_unique_tags_by_bucket.cte

        cumulative_unique_tag_series = TimeSeries.cumulative_unique_tag_series_query(
          bucketed_time_series,
          sum_unique_tags_by_bucket
        )
        accumulation_series_ctes << cumulative_unique_tag_series.cte

        series_aliased = cumulative_unique_tag_series.table.as('t')
        aggregate = Arel::SelectManager.new
          .project(series_aliased.right.row_to_json.json_agg)
          .from(series_aliased)

        [accumulation_series_ctes, aggregate]
      end
    end
  end
end
