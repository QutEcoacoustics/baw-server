# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # TODO: might be a good idea to return the gap size value in the report
      class IntervalGapSize < Report::Cte::NodeTemplate
        table_name :interval_gap_size

        default_options start_time: nil, end_time: nil, scaling_factor: 1920

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
