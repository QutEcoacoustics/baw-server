# frozen_string_literal: true

module Api
  module Reporting
    # Generic time-series bucketing utility.
    # Generates a series of [t, t+interval) tsrange buckets, covering the
    # minimum `start_at` to the maximum `end_at` from the given events table.
    # Used by report templates (e.g. TagAccumulation) that need time-bucketed
    # aggregation.
    class Bucketer
      include CteHelper

      BOUNDS  = Arel::Table.new(:bounds)
      BUCKETS = Arel::Table.new(:audio_event_buckets)

      INTERVALS = {
        'day' => { days: 1 },
        'week' => { weeks: 1 },
        'month' => { months: 1 },
        'year' => { years: 1 }
      }.freeze

      Options = Data.define(:bucket_size) {
        def interval_hash = INTERVALS.fetch(bucket_size) { raise KeyError, "#{bucket_size} not in #{INTERVALS.keys}" }
        def interval_arel = Baw::Arel::Nodes::MakeInterval.new(**interval_hash)
      }

      attr_reader :options

      # @param options [Hash]
      # @option options [String] :bucket_size required
      def initialize(options = {})
        @options = Options.new(**options)
      end

      # Returns the two bucket-related CTEs [bounds, buckets]
      # @param events_table [Arel::Table] the CTE table containing start_at/end_at columns
      # @return [Array<Arel::Nodes::As>]
      def bucket_ctes(events_table:)
        [
          cte(BOUNDS, bounds_cte(events_table, @options.bucket_size)),
          cte(BUCKETS, buckets_cte(@options.interval_arel))
        ]
      end

      private

      # Use the events to determine bounds for generating the bucket series
      def bounds_cte(events_table, interval)
        events_table.project(
          Arel.date_trunc(interval, events_table[:start_at].minimum).as('series_start'),
          Arel.date_trunc(interval, events_table[:end_at].maximum).as('series_end')
        )
      end

      # Using the bounds and supplied bucket interval to generate the main bucket cte
      def buckets_cte(interval_arel)
        series = Arel.generate_series(BOUNDS[:series_start], BOUNDS[:series_end], interval_arel).as('bucket_lower')
        lower = series.right
        upper = Arel::Nodes::InfixOperation.new('+', lower, interval_arel)

        # Without `.on` Arel generates INNER JOIN LATERAL (not CROSS JOIN LATERAL?)
        # which causes a syntax error
        BOUNDS
            .project(Arel.tsrange(lower, upper).as('bucket'))
            .join(Arel::Nodes::Lateral.new(series))
            .on(Arel.sql('true'))
      end
    end
  end
end
