# frozen_string_literal: true

module Report
  # Provides functionality for analysing and reporting time series data.
  module TimeSeries
    module_function

    extend Report::ArelHelpers
    include Report::ArelHelpers

    # A hash mapping of valid bucket size strings (keys) for reporting
    #   and their corresponding PostgreSQL interval strings (values).
    BUCKET_ENUM = {
      'day' => '1 day',
      'week' => '1 week',
      'fortnight' => '2 week',
      'month' => '1 month',
      'year' => '1 year'
    }.freeze

    # Get the interval string for a bucket from BUCKET_ENUM
    # @param bucket [String] the bucket size
    # @return [String] the bucket interval string
    def bucket_interval(bucket_size)
      BUCKET_ENUM[bucket_size] || '1 day'
    end

    # Return a validated hash of time series reporting values from params
    class StartEndTime
      # @param [Hash] parameters to parse
      # @param [Proc] time_range_parser a proc that returns an array of the
      #   report start and end datetime strings from the input parameters.
      # @param [Proc] bucket_size_parser a proc that returns a valid bucket size
      #   string from the input parameters
      # @return [Hash] with keys :start_time, :end_time, :bucket_size, :interval
      def self.call(parameters,
                    time_range_parser: TimeSeries.parse_time_range,
                    bucket_size_parser: TimeSeries.parse_bucket_size)
        time_range = time_range_parser.call(parameters)
        start_time, end_time = validate_start_end_time(time_range)

        parsed_bucket = bucket_size_parser.call(parameters)
        bucket_size = validate_bucket_size(parsed_bucket)

        {
          start_time: start_time,
          end_time: end_time,
          bucket_size: bucket_size,
          interval: TimeSeries.bucket_interval(bucket_size)
        }
      end

      # Reports allow future dates; requests will emit empty results but can be
      # reused to show data as it becomes available.
      def self.validate_start_end_time(time_range)
        start_time, end_time = time_range.map { |time| TimeSeries.string_to_iso8601(time) }

        raise ArgumentError, "invalid time range, #{start_time} is > #{end_time}" unless start_time < end_time

        Rails.logger.warn('future start time') if start_time > Time.zone.now
        Rails.logger.warn('future end time') if end_time > Time.zone.now

        [start_time, end_time]
      end

      def self.validate_bucket_size(bucket)
        return bucket if BUCKET_ENUM.keys.include?(bucket)

        message = if bucket.nil?
                    'No bucket size specified.'
                  else
                    "Invalid bucket size: #{bucket}."
                  end

        Rails.logger.warn("#{message} Defaulting to 'day'.")
        'day'
      end
    end

    def string_to_iso8601(datetime_string)
      begin
        datetime = DateTime.iso8601(datetime_string)
      rescue ArgumentError
        raise ArgumentError, 'time string must be valid ISO 8601 dates.'
      end
      datetime
    end

    def parse_time_range_from_request_params
      lambda { |parameters|
        start_time = parameters.dig(:options, :start_time)
        end_time = parameters.dig(:options, :end_time)
        [start_time, end_time]
      }
    end

    def parse_bucket_size_from_request_params
      lambda { |parameters|
        bucket = parameters.dig(:options, :bucket_size)
        bucket
      }
    end

    # @param start_date [String] Start date in ISO format
    # @param end_date [String] End date in ISO format
    # @param bucket_interval [String] PostgreSQL interval string e.g. '1 hour'
    # @return [Query] A query object with the time boundaries as a tsrange
    def time_range_and_interval_query(time_series_config)
      start_date = time_series_config[:start_time]
      end_date = time_series_config[:end_time]

      # cast(:datetime) => AS timestamp without time zone by default
      start_date = Arel.quoted(start_date).cast(:datetime)
      end_date = Arel.quoted(end_date).cast(:datetime)

      bucket_interval = time_series_config[:interval]
      bucket_interval_quoted = Arel.sql('INTERVAL ?', Arel.quoted(bucket_interval))

      select = manager
        .project(
          time_range_expression(start_date, end_date).as('time_range'),
          bucket_interval_quoted.as('bucket_interval')
        )

      table = Arel::Table.new(:time_range_and_interval)
      cte = Arel::Nodes::As.new(table, select)
      ReportQuery.new(table, cte)
    end

    # closed open time range from [start_date, end_date)
    def time_range_expression(start_date, end_date)
      Arel::Nodes::NamedFunction.new(
        'tsrange', [
          start_date,
          end_date,
          Arel.quoted('[)')
        ]
      )
    end

    # Generate a cte to calculate the minimum number of buckets required to
    #   cover a given time range and interval (e.g. 1 day, 1 month, etc.)
    # @param [Query] time_range_and_interval cte returning tsrange
    # @param [string] interval the bucket interval is used to determine
    #   how the number of buckets will be calculated
    def number_of_buckets_query(time_range_and_interval, interval)
      bucket_count_expr = case interval
                          when '1 month'
                            TimeSeries.count_number_of_buckets_monthly(time_range_and_interval, interval)
                          when '1 year'
                            TimeSeries.count_number_of_buckets_yearly(time_range_and_interval, interval)
                          else
                            TimeSeries.count_number_of_buckets_default(time_range_and_interval, interval)
                          end

      select = Arel::SelectManager.new
        .project(
          time_range_and_interval.table[:time_range],
          time_range_and_interval.table[:bucket_interval],
          bucket_count_expr.as('bucket_count')
        )
        .from(time_range_and_interval.table)

      table = Arel::Table.new('number_of_buckets')
      cte = Arel::Nodes::As.new(table, select)
      ReportQuery.new(table, cte)
    end

    # no built in upper method unlike lower?
    def upper(expr)
      Arel::Nodes::NamedFunction.new('upper', [expr])
    end

    # Default method to calculate number of buckets needed to cover a time range
    # @param time_range_and_interval [Query] cte returning tsrange
    # @param interval [String] the bucket interval
    # #return [Arel::SelectManager] query
    def count_number_of_buckets_default(time_range_and_interval, interval)
      t = time_range_and_interval.table
      max = upper(t[:time_range]).extract('epoch')
      min = t[:time_range].lower.extract('epoch')
      bin = t[:bucket_interval].extract('epoch')
      difference = max - min
      t.project(difference / bin)
    end

    # Truncate a date to the specified interval
    def date_trunc(interval, expr)
      Arel::Nodes::NamedFunction.new('date_trunc', [Arel.quoted(interval), expr])
    end

    # Calculate number of buckets needed to cover a time range for special case
    #   of month interval
    # @param time_range_and_interval [Query] cte returning tsrange
    # @param interval [String] the bucket interval
    # #return [Arel::SelectManager] query
    def count_number_of_buckets_monthly(time_range_and_interval, interval)
      t = time_range_and_interval.table

      end_time = upper(t[:time_range])
      start_time = t[:time_range].lower

      end_year = end_time.extract('year')
      start_year = start_time.extract('year')

      end_month = end_time.extract('month')
      start_month = start_time.extract('month')

      # subtracting a timestamp truncated to month from itself gives the
      # remainder of days + hours:minutes:seconds. if the end time remainder is
      # greater than the start time, there is a partial month, so add 1
      end_remainder = end_time - date_trunc('month', end_time)
      start_remainder = start_time - date_trunc('month', start_time)

      partial_bucket = Arel::Nodes::Case.new
        .when(end_remainder > start_remainder).then(1).else(0)

      t.project(((end_year - start_year) * 12) + (end_month - start_month) + partial_bucket)
    end

    # Calculate number of buckets needed to cover a time range for special case
    #   of year interval
    # @param time_range_and_interval [Query] cte returning tsrange
    # @param interval [String] the bucket interval
    # #return [Arel::SelectManager] query
    def count_number_of_buckets_yearly(time_range_and_interval, interval)
      t = time_range_and_interval.table

      end_time = upper(t[:time_range])
      start_time = t[:time_range].lower

      end_year = end_time.extract('year')
      start_year = start_time.extract('year')

      end_remainder = end_time - date_trunc('year', end_time)
      start_remainder = start_time - date_trunc('year', start_time)

      partial_bucket = Arel::Nodes::Case.new
        .when(end_remainder > start_remainder).then(1).else(0)

      t.project(end_year - start_year + partial_bucket)
    end

    # Generate a series of tsrange values, one for each bucket, that will be used
    #   to group the data in the report
    # @param number_of_buckets [Query] cte returning number of buckets column
    # @return [Query] A query object with the bucketed time series
    #   and the bucket number
    def bucketed_time_series_query(number_of_buckets)
      # generate the series of integers from 1 to the number of buckets, which
      # will cross join with the report's tsrange
      series = TimeSeries.generate_series(number_of_buckets.table[:bucket_count].ceil).to_sql
      series_alias = Arel.sql('bucket_number')

      # create a ts range for each bucket in the generated series
      range_from = Arel.sql('lower(time_range) + ((? - 1) * bucket_interval)', series_alias)
      range_to = Arel.sql('lower(time_range) + (? * bucket_interval)', series_alias)
      ts_range = Arel.sql('tsrange(?, ?)', range_from, range_to).as('time_bucket')

      query = manager.project(series_alias, ts_range)
        .from(number_of_buckets.table)
        .join(Arel.sql("CROSS JOIN #{series} AS #{series_alias}"))

      table = Arel::Table.new('bucketed_time_series')

      cte = Arel::Nodes::As.new(table, query)
      ReportQuery.new(table, cte)
    end

    # Generate a series of integers from 1 to the specified end
    # @param stop_expr [String] Stop expression for the series
    # @return [Arel::Nodes::NamedFunction]
    def generate_series(expr)
      Arel::Nodes::NamedFunction.new('generate_series', [1, expr])
    end

    def bucket_count_default(start_column, end_column, interval_column)
      # extract(epoch from ?)
      (end_column.extract('epoch') - start_column.extract('epoch')) / interval_column.extract('epoch')
    end

    # Generate bucket time series sql
    # @param start_date [String] Start date in ISO format
    # @param end_date [String] End date in ISO format
    # @param bucket_interval [String] PostgreSQL interval string e.g. '1 hour'
    # @return [String] SQL for generating bucket boundaries
    def time_series(start_date, end_date, bucket_interval)
      bucket_count_case = case bucket_interval
                          when '1 month' then expr_bucket_count_month
                          when '1 year' then expr_bucket_count_year
                          else expr_bucket_count_default
                          end

      time_boundaries = cte_time_boundaries(start_date, end_date, bucket_interval)
      calculated_settings = cte_calculated_settings(bucket_count_case)
      all_buckets = cte_all_buckets
      Arel.sql(
       <<~SQL.squish
         #{time_boundaries},
         #{calculated_settings},
         #{all_buckets}
       SQL
     )
    end

    def extract_epoch(expr)
      Arel::Nodes::NamedFunction.new('EXTRACT', ['EPOCH', expr])
    end

    # Use the width_bucket function to return a cte that categorises input data
    #  by bucket number
    def allocate_bucket_based_on_start_time_abosolute(base_table, number_of_buckets)
      nb_table = number_of_buckets.table
      width_bucket_expr = Arel::Nodes::NamedFunction.new('width_bucket', [
        base_table[:start_time_absolute].extract('epoch'),
        nb_table.project(nb_table[:time_range].lower.extract('epoch')),
        nb_table.project(TimeSeries.upper(nb_table[:time_range]).extract('epoch')),
        nb_table.project(nb_table[:bucket_count].ceil.cast('int'))
      ])

      select = Arel::SelectManager.new
        .project([
          width_bucket_expr.as('bucket'),
          base_table[:tag_id],
          base_table[:score]
        ])
        .from(base_table)

      table = Arel::Table.new('data_with_allocated_bucket')
      cte = Arel::Nodes::As.new(table, select)

      ReportQuery.new(table, cte)
    end

    # To get an accumulated count of unique tags, we first need to know where
    # the tag is first seem (at which bucket).
    def tag_first_appearance_query(data_with_allocated_bucket)
      t = data_with_allocated_bucket.table
      window = Arel::Nodes::Window.new.partition(t[:tag_id]).order(t[:bucket])
      tag_first_appearance = Arel::Nodes::Case.new
        .when(Arel::Nodes::NamedFunction.new('row_number', []).over(window).eq(1))
        .then(1).else(0)

      select = Arel::SelectManager.new
        .project(t[:bucket], t[:tag_id], t[:score], tag_first_appearance.as('is_first_time'))
        .from(t)
        .where(t[:bucket].eq(nil).invert)

      table = Arel::Table.new('tag_first_appearance')
      cte = Arel::Nodes::As.new(table, select)
      ReportQuery.new(table, cte)
    end

    # get the sum of new unique tags in each bucket
    def sum_unique_tags_by_bucket_query(tag_first_appearance)
      t = tag_first_appearance.table

      # get the sum of new unique tags in each bucket
      select = manager.project(
        t[:is_first_time].sum.as('sum_new_tags'),
        t[:bucket]
      ).group(t[:bucket]).from(t)

      table = Arel::Table.new('sum_groups')
      cte = Arel::Nodes::As.new(table, select)
      ReportQuery.new(table, cte)
    end

    # Use the sum of new unique tags in each bucket to get the cumulative
    # count of unique tags in each bucket.
    # @return [ReportQuery] A query object with the cumulative unique tag series
    #   and the bucket number, with the tsrange for each bucket and the
    #   corresponding cumulative count of unique tags
    def cumulative_unique_tag_series_query(bucketed_time_series, sum_unique_tags_by_bucket)
      t = bucketed_time_series.table

      # create a sum over window ordered by the time series bucket numbers
      window = Arel::Nodes::Window.new.order(t[:bucket_number])
      sum_unique_tags_over_window = sum_unique_tags_by_bucket.table[:sum_new_tags].sum.over(window)

      select = Arel::SelectManager.new
        .project(
          t[:bucket_number],
          t[:time_bucket].as('range'),
          sum_unique_tags_over_window.coalesce(0).cast('int').as('count')
        ).from(t)
        # outer join the sums with the full bucket time series to get all
        # bins as data points
        .join(sum_unique_tags_by_bucket.table, Arel::Nodes::OuterJoin)
        .on(t[:bucket_number].eq(sum_unique_tags_by_bucket.table[:bucket]))
        .order(t[:bucket_number].asc)

      table = Arel::Table.new('cumulative_unique_tag_series')
      cte = Arel::Nodes::As.new(table, select)
      ReportQuery.new(table, cte)
    end

    def datetime_range_to_array(start_field, end_field)
      Arel::Nodes::SqlLiteral.new("
          array_to_json(ARRAY[
            to_char(#{start_date}, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
            to_char(#{end_date}, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')
          ])
        ").as('range')
    end
  end
end

# problem with epoch for buckets
# probably need a parameter for the report - what time zone do you want the
# report in
# e.g. state boundaries - need to know one or the other

# if report start provided by user, this should be the epoch we use - no rounding
# without start date, have to calculate the epoch e.g.
