# frozen_string_literal: true

module Report
  module Ctes
    module Accumulation
      # This CTE provides the basis configuration for bucket related steps.
      #
      # Defines a CTE that generates the count of time buckets required to cover
      # a time range (e.g. a reporting period). Bucket size is set using the
      # interval option.
      #
      # == query output
      #
      #  emits columns:
      #    time_range       (tsrange)
      #    bucket_interval  (interval)
      #    bucket_count     (numeric)  -- total buckets of length bucket_interval required to cover time_range
      class BucketCount < Cte::NodeTemplate
        include Report::Validation
        extend Report::TimeSeries

        table_name :bucket_count

        dependencies ts_range: TimeRangeAndInterval

        # TODO: enforce required options for dependent CTEs.
        # This CTE needs an explicit :interval, and its dependency TimeRangeAndInterval
        # also accepts options. Relying on defaults can mask missing settings.
        # We should validate or document exactly which options each dependency requires.
        options do
          {
            interval: '1 day'
          }
        end

        validate_with Report::Validation::Interval

        select do
          calculator = interval_calculators[options[:interval]] || interval_calculators['default']
          bucket_count_expr = calculator.call(ts_range)

          ts_range.project(
            ts_range[:time_range],
            ts_range[:bucket_interval],
            bucket_count_expr.as('bucket_count')
          )
        end

        # Calculate the minimum number of buckets to cover the report time
        # range.
        #
        # For fixed intervals (days, weeks), divide the total duration
        # by the bucket size. For variable-length intervals (months, years),
        # apply custom logic to account for their varying lengths.
        #
        # @return [Hash{String => Proc}] a mapping of interval strings to their
        # corresponding calculation lambdas
        def self.interval_calculators
          # don't let the cop add a space before the division operator
          # rubocop:disable Style/SpaceAroundOperators
          @interval_calculators ||= {
            'default' => lambda { |ts_range|
              bounds_for(ts_range, :time_range) do |lower, upper|
                ts_range.project(
                  time_difference(upper, lower, 'epoch')/
                  ts_range[:bucket_interval].extract('epoch')
                )
              end
            },
            '1 month' => lambda { |ts_range|
              bounds_for(ts_range, :time_range) do |lower, upper|
                ts_range.project((
                  time_difference(upper, lower, 'year') * 12) +
                  time_difference(upper, lower, 'month') +
                  partial_bucket_count(upper, lower, 'month'))
              end
            },

            '1 year' => lambda { |ts_range|
              bounds_for(ts_range, :time_range) do |lower, upper|
                ts_range.project(
                  time_difference(upper, lower, 'year') +
                  partial_bucket_count(upper, lower, 'year')
                )
              end
            }
          }
        end

        # Return or yield an array of [lower, upper] bounds of a time range field
        #
        # Note: In the usage above, field is 'time_range' (type tsrange) on the
        #   ts_range table the result of calling lower or upper on tsrange is a
        #   timestamp without time zone type
        def self.bounds_for(table, field)
          bounds = [table[field].lower, upper(table[field])]
          block_given? ? yield(bounds) : bounds
        end

        def self.time_difference(upper, lower, unit)
          upper.extract(unit) - lower.extract(unit)
        end

        # Add 1 to the bucket count if the time range has a partial month or
        #   year. Subtracting a datetime truncated to month/year from itself
        #   gives a remainder of days + hours:minutes:seconds. If the upper
        #   remainder is greater than the lower, add 1 to the bucket count to
        #   cover the remainder
        def self.partial_bucket_count(upper_ts, lower_ts, unit)
          Arel::Nodes::Case.new.when(
            (upper_ts - date_trunc(unit, upper_ts)) >
            (lower_ts - date_trunc(unit, lower_ts))
          ).then(1).else(0)
        end
      end
    end
  end
end
