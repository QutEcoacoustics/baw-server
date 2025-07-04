# frozen_string_literal: true

# rubocop:disable Style/ClassAndModuleChildren
class Report::Section::Accumulation < Report::Section
  extend Report::TimeSeries

  # Table constants for each step
  TABLE_TIME_RANGE_AND_INTERVAL = :time_range_and_interval
  TABLE_NUMBER_OF_BUCKETS = :number_of_buckets
  TABLE_BUCKETED_TIME_SERIES = :bucketed_time_series
  TABLE_DATA_WITH_ALLOCATED_BUCKET = :data_with_allocated_bucket
  TABLE_TAG_FIRST_APPEARANCE = :tag_first_appearance
  TABLE_SUM_UNIQUE_TAGS_BY_BUCKET = :sum_unique_tags_by_bucket
  CUMULATIVE_UNIQUE_TAG = :cumulative_unique_tag_series

  TABLES = {
    time_range_and_interval: TABLE_TIME_RANGE_AND_INTERVAL,
    number_of_buckets: TABLE_NUMBER_OF_BUCKETS,
    bucketed_time_series: TABLE_BUCKETED_TIME_SERIES,
    data_with_allocated_bucket: TABLE_DATA_WITH_ALLOCATED_BUCKET,
    tag_first_appearance: TABLE_TAG_FIRST_APPEARANCE,
    sum_unique_tags_by_bucket: TABLE_SUM_UNIQUE_TAGS_BY_BUCKET,
    cumulative_unique_tag_series: CUMULATIVE_UNIQUE_TAG
  }.freeze

  # special cased interval bucket counting methods
  INTERVAL_COUNTERS = {
    '1 month' => :count_number_of_buckets_monthly,
    '1 year' => :count_number_of_buckets_yearly
  }.freeze

  def default_options
    {
      base_table: nil,
      start_time: nil,
      end_time: nil,
      bucket_size: 'day',
      interval: '1 day'
    }
  end

  step TABLE_TIME_RANGE_AND_INTERVAL do |options|
    time_range_and_interval_query(options)
  end

  step TABLE_NUMBER_OF_BUCKETS, depends_on: TABLE_TIME_RANGE_AND_INTERVAL do |time_range_and_interval, options|
    number_of_buckets_query(time_range_and_interval, options[:interval])
  end

  step TABLE_BUCKETED_TIME_SERIES, depends_on: TABLE_NUMBER_OF_BUCKETS do |number_of_buckets|
    bucketed_time_series_query(number_of_buckets)
  end

  step TABLE_DATA_WITH_ALLOCATED_BUCKET, depends_on: TABLE_NUMBER_OF_BUCKETS do |number_of_buckets, options|
    allocate_bucket_based_on_start_time_abosolute(options[:base_table], number_of_buckets)
  end

  step TABLE_TAG_FIRST_APPEARANCE, depends_on: TABLE_DATA_WITH_ALLOCATED_BUCKET do |data_with_allocated_bucket|
    tag_first_appearance_query(data_with_allocated_bucket)
  end

  step TABLE_SUM_UNIQUE_TAGS_BY_BUCKET, depends_on: TABLE_TAG_FIRST_APPEARANCE do |tag_first_appearance|
    sum_unique_tags_by_bucket_query(tag_first_appearance)
  end

  step CUMULATIVE_UNIQUE_TAG,
    depends_on: [TABLE_BUCKETED_TIME_SERIES, TABLE_SUM_UNIQUE_TAGS_BY_BUCKET] do |bts, sut|
    cumulative_unique_tag_series_query(bts, sut)
  end

  # Return a query that projects the aggregated accumulation result
  # @param collection [Report::Collection]
  def project(_collection = nil, _options = nil)
    cumulative_table_aliased = CUMULATIVE_UNIQUE_TAG.as('t')
    Arel::SelectManager.new
      .project(cumulative_table_aliased.right.row_to_json.json_agg)
      .from(cumulative_table_aliased)
  end

  class << self
    # Return a query that projects a given reporting start and end time as a
    # tsrange, and a bucket size as an INTERVAL.
    #
    # @param opts [Hash] options for time series see Report::TimeSeries.options
    # @option opts [DateTime] :start_time The start time of the time range
    # @option opts [DateTime] :end_time The end time of the time range
    # @option opts [String] :interval (e.g. '1 day', '1 month')
    def time_range_and_interval_query(opts)
      lower, upper, interval = opts.values_at(:start_time, :end_time, :interval)
      arel_tsrange_expr = arel_tsrange(
        arel_cast_datetime(lower),
        arel_cast_datetime(upper)
      ).as('time_range')
      bucket_interval_expr = arel_interval(interval).as('bucket_interval')
      Arel::SelectManager.new.project(arel_tsrange_expr, bucket_interval_expr)
    end

    # Return a query that calculates the minimum number of buckets required to
    # cover a given time range using an interval (e.g. 1 day, 1 month, etc.)
    #
    # @param [Arel::Table] {TABLE_TIME_RANGE_AND_INTERVAL}
    # @param [string] interval the bucket interval is used to determine
    #   how the number of buckets will be calculated
    # # @return [Arel::SelectManager]
    def number_of_buckets_query(time_range_and_interval, interval)
      # pick the counting method for special cases, else use the default
      counter = INTERVAL_COUNTERS.fetch(interval, :count_number_of_buckets_default)
      bucket_count_expr = send(counter, time_range_and_interval)

      time_range_and_interval.project(
        time_range_and_interval[:time_range],
        time_range_and_interval[:bucket_interval],
        bucket_count_expr.as('bucket_count')
      )
    end

    # Default method to calculate number of buckets needed to cover a time
    # range
    #
    # @param time_range_and_interval [Arel::Table] {TABLE_TIME_RANGE_AND_INTERVAL}
    # #return [Arel::SelectManager]
    def count_number_of_buckets_default(time_range_and_interval)
      # rubocop:disable Layout/SpaceAroundOperators
      t = time_range_and_interval
      t.project(
        (upper(t[:time_range]).extract('epoch') - t[:time_range].lower.extract('epoch'))/
        t[:bucket_interval].extract('epoch')
      )
      # rubocop:enable Layout/SpaceAroundOperators
    end

    # Calculate number of buckets needed to cover a time range for special case
    # of month interval
    #
    # @param time_range_and_interval [Query] cte returning tsrange
    # #return [Arel::SelectManager] query
    def count_number_of_buckets_monthly(time_range_and_interval)
      lower, upper = bounds(time_range_and_interval, :time_range)
      months_diff  = ((upper.extract('year') - lower.extract('year')) * 12) +
                     (upper.extract('month') - lower.extract('month'))

      partial = partial_bucket_counter(lower, upper, 'month')

      time_range_and_interval.project((months_diff + partial))
    end

    # Calculate number of buckets needed to cover a time range for special
    #   case of year interval
    # @param time_range_and_interval [Arel::Table]
    # #return [Arel::SelectManager] query
    def count_number_of_buckets_yearly(time_range_and_interval)
      lower, upper = bounds(time_range_and_interval, :time_range)
      years_diff   = upper.extract('year') - lower.extract('year')

      partial = partial_bucket_counter(lower, upper, 'year')

      time_range_and_interval.project(years_diff + partial)
    end

    # helper to return upper and lower bounds of a time range field
    def bounds(table, field)
      lower_ts = table[field].lower
      upper_ts = upper(table[field])
      [lower_ts, upper_ts]
    end

    # Add 1 to the bucket count if the time range has a partial month or year.
    # subtracting a datetime truncated to month/year from itself gives a
    # remainder of days + hours:minutes:seconds. if the upper remainder is
    # greater than the lower, add 1 to the bucket count to cover the remainder
    def partial_bucket_case(lower_ts, upper_ts, unit)
      Arel::Nodes::Case.new.when(
        (upper_ts - date_trunc(unit, upper_ts)) >
        (lower_ts - date_trunc(unit, lower_ts))
      ).then(1).else(0)
    end

    # Generate a series of tsrange values, one for each bucket, that will be
    # used to aggregate time series data.
    #
    # @param [Arel::Table] number_of_buckets {TABLE_NUMBER_OF_BUCKETS}
    # @return [Arel::SelectManager]
    def bucketed_time_series_query(number_of_buckets)
      # integers from 1 to the number of buckets, to cross join with the
      # report's tsrange
      series = generate_series(number_of_buckets[:bucket_count].ceil).to_sql
      series_alias = Arel.sql('bucket_number')
      range_from = Arel.sql('lower(time_range) + ((? - 1) * bucket_interval)', series_alias)
      range_to = Arel.sql('lower(time_range) + (? * bucket_interval)', series_alias)
      ts_range = Arel.sql('tsrange(?, ?)', range_from, range_to).as('time_bucket')

      number_of_buckets
        .project(series_alias, ts_range)
        .join(Arel.sql("CROSS JOIN #{series} AS #{series_alias}"))
    end

    # Use the width_bucket function to return a query that categorises input
    # data by bucket number
    def allocate_bucket_based_on_start_time_abosolute(base_table, number_of_buckets)
      width_bucket_expr = Arel::Nodes::NamedFunction.new('width_bucket', [
        base_table[:start_time_absolute].extract('epoch'),
        number_of_buckets.project(number_of_buckets[:time_range].lower.extract('epoch')),
        number_of_buckets.project(upper(number_of_buckets[:time_range]).extract('epoch')),
        number_of_buckets.project(number_of_buckets[:bucket_count].ceil.cast('int'))
      ])
      base_table.project(
        width_bucket_expr.as('bucket'),
        base_table[:tag_id],
        base_table[:score]
      )
    end

    # To get an accumulated count of unique tags, we first need to know where
    # the tag is first seem (at which bucket).
    def tag_first_appearance_query(t)
      window = Arel::Nodes::Window.new.partition(t[:tag_id]).order(t[:bucket])
      tag_first_appearance = Arel::Nodes::Case.new.when(
        Arel::Nodes::NamedFunction.new('row_number', []).over(window).eq(1)
      ).then(1).else(0)

      t.project(
        t[:bucket], t[:tag_id], t[:score],
        tag_first_appearance.as('is_first_time')
      ).where(t[:bucket].eq(nil).invert)
    end

    # get the sum of new unique tags in each bucket
    def sum_unique_tags_by_bucket_query(t)
      t.project(
        t[:is_first_time].sum.as('sum_new_tags'),
        t[:bucket]
      ).group(t[:bucket])
    end

    # Use the sum of new unique tags in each bucket to get the cumulative
    # count of unique tags in each bucket.
    def cumulative_unique_tag_series_query(t, sum_unique_tags_by_bucket)
      window = Arel::Nodes::Window.new.order(t[:bucket_number])
      sum_unique_tags_over_window = sum_unique_tags_by_bucket[:sum_new_tags].sum.over(window)
      t.project(
        t[:bucket_number],
        t[:time_bucket].as('range'),
        sum_unique_tags_over_window.coalesce(0).cast('int').as('count')
      )
        # outer join the sums with the full bucket time series to get all
        # bins as data points
        .join(sum_unique_tags_by_bucket, Arel::Nodes::OuterJoin)
        .on(t[:bucket_number].eq(sum_unique_tags_by_bucket[:bucket]))
        .order(t[:bucket_number].asc)
    end
  end
end
