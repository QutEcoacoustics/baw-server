# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # Defines a CTE that calculates a single `gap_size` interval value.
      #
      # This value represents the minimum duration between two temporal events
      # for them to be considered part of separate, discontinuous intervals.
      # It is calculated by dividing the total duration of the report's time
      # range by a scaling factor.
      #
      # == query output
      #
      #  emits column: gap_size (interval) -- the calculated minimum gap size
      #
      # @todo It might be a good idea to return the calculated gap size value in the report
      class IntervalGapSize < Cte::NodeTemplate
        table_name :interval_gap_size

        # @param options [Hash] the default options hash
        # @option options [Time] :start_time The start of the time range (required)
        # @option options [Time] :end_time The end of the time range (required)
        # @option options [Integer] :scaling_factor (1920) The scaling factor to use for coverage
        options start_time: nil, end_time: nil, scaling_factor: 1920

        select do
          start_time, end_time, scaling_factor = options.values_at(:start_time, :end_time, :scaling_factor)
          report_range = Report::TimeSeries.arel_project_ts_range(start_time, end_time)
          report_range_interval = range_interval(report_range, scaling_factor)

          Arel::SelectManager.new
            .project(report_range_interval.as('gap_size'))
            .from(report_range)
        end

        def self.range_interval(report_range, scaling_factor)
          upper_epoch = Report::TimeSeries.upper(report_range[:range]).extract('epoch')
          lower_epoch = report_range[:range].lower.extract('epoch')

          seconds = upper_epoch - lower_epoch
          scaled_seconds = seconds / scaling_factor

          arel_seconds_to_interval(scaled_seconds)
        end

        def self.arel_seconds_to_interval(seconds)
          Arel::Nodes::NamedFunction.new(
            'make_interval',
            [Arel.sql('secs => ?', seconds)]
          )
        end
      end
    end
  end
end
