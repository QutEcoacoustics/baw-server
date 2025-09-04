# frozen_string_literal: true

module Report
  module Ctes
    class BucketCount < Report::Cte::Node
      extend Report::TimeSeries

      include Cte::Dsl
      include Report::ValidateOptions

      table_name :bucket_count

      depends_on ts_range: Report::Ctes::TsRangeAndInterval

      # ! need to think about options patterns some more
      # ! interval is needed here explicitly but dependency ts_range also needs options. it has defaults
      # ! so it would work without, but probably should not. so should have some kind of required options setting?
      # ! so if a dependency cte has required options, you would need to pass those in when using a node that depends on it
      # another example, if using Ctes::EventComposition, it's not clear that you should pass options that will go down
      # to tsrangeandinterval
      default_options do
        {
          interval: '1 day'
        }
      end

      validate_with Report::IntervalContract

      select do
        # at this stage, the 'interval' field is already a projected field on the dependency table TsRangeAndInterval,
        # but we can just check the options field again to select the appropriate calculation method
        calculator = interval_calculators[options[:interval]] || interval_calculators['default']
        bucket_count_expr = calculator.call(ts_range)

        ts_range.project(
          ts_range[:time_range],
          ts_range[:bucket_interval],
          bucket_count_expr.as('bucket_count')
        )
      end

      # the point of this step is to calculate the minimum number of buckets that cover the report time range in the
      # default case, such as daily or weekly buckets, it's a simple division of the time range duration by the bucket
      # interval duration. but for 'month' and 'year' intervals, the default calculation is not accurate because months
      # and years have variable lengths. so we need special calculations for those cases.
      def self.interval_calculators
        # don't let the cop add a space before the division operator
        # rubocop:disable Layout/SpaceAroundOperators
        @interval_calculators ||= {
          'default' => lambda { |ts_range|
            ts_range.project(
              (upper(ts_range[:time_range]).extract('epoch') -
                ts_range[:time_range].lower.extract('epoch'))/
              ts_range[:bucket_interval].extract('epoch')
            )
          },
          '1 month' => lambda { |ts_range|
            lower, upper = bounds(ts_range, :time_range)
            months_diff = ((upper.extract('year') - lower.extract('year')) * 12) +
                          (upper.extract('month') - lower.extract('month'))
            partial = partial_bucket_counter(lower, upper, 'month')
            ts_range.project(months_diff + partial)
          },
          '1 year' => lambda { |ts_range|
            lower, upper = bounds(ts_range, :time_range)
            years_diff = upper.extract('year') - lower.extract('year')
            partial = partial_bucket_counter(lower, upper, 'year')
            ts_range.project(years_diff + partial)
          }
        }
      end

      # helper to return upper and lower bounds of a time range field
      def self.bounds(table, field)
        lower_ts = table[field].lower
        upper_ts = upper(table[field])
        [lower_ts, upper_ts]
      end

      # Add 1 to the bucket count if the time range has a partial month or year.
      # subtracting a datetime truncated to month/year from itself gives a
      # remainder of days + hours:minutes:seconds. if the upper remainder is
      # greater than the lower, add 1 to the bucket count to cover the remainder
      def self.partial_bucket_case(lower_ts, upper_ts, unit)
        Arel::Nodes::Case.new.when(
          (upper_ts - date_trunc(unit, upper_ts)) >
          (lower_ts - date_trunc(unit, lower_ts))
        ).then(1).else(0)
      end
    end
  end
end
