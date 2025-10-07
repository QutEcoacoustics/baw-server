# frozen_string_literal: true

module Report
  module Ctes
    #
    # The Coverage module provides a namespace for CTE templates used for
    # calculating temporal coverage of events, such as audio recordings.
    #
    # It works by grouping discrete temporal events into continuous intervals
    # and then calculating the density of actual event coverage within each
    # interval. This is useful for visualising the completeness of a dataset
    # over a time range.
    #
    # A 'gap size' appraoch is used to determine when events are considered part
    # of the same continuous interval or separate intervals. This means the
    # number of intervals emitted won't exceed a set scaling factor (such as
    # pixels available to display the graphed result).
    #
    module Coverage
      #
      # Root CTE template for a temporal coverage result.
      #
      # Defines a CTE that formats the results of {IntervalDensity} into a JSON
      # array representing the coverage series.
      #
      # The `analysis_result` option can be used to calculate the coverage of
      # audio_events by distinct analysis result types.
      #
      # == query output
      #
      #  emits column:
      #    coverage (json) -- an array of coverage interval objects. The name of
      #                       this column is dynamic and depends on the table_name
      #                       of the node instance.
      #
      #  emits json fields in coverage[*]:
      #    range (string)                   -- tsrange literal in canonical form, inclusive start, exclusive end
      #    density (numeric)                -- the density ([0,1], rounded to 3 places) of events in the interval
      #    type (analysis_jobs_item_result) -- (optional) the analysis result type, if `analysis_result` is true
      #
      # @example Basic usage
      #   result = Report::Ctes::Coverage::Coverage.execute
      #   series = Report::Ctes::Coverage::Coverage.format_result(result.first)
      #
      class Coverage < Cte::NodeTemplate
        table_name :coverage

        dependencies interval_density: Report::Ctes::Coverage::IntervalDensity

        options analysis_result: false

        select do
          range = Report::TimeSeries.arel_tsrange(interval_density[:coverage_start], interval_density[:coverage_end])
          fields = { 'range' => range, 'density' => interval_density[:density].round(3) }

          fields = fields.merge('type' => interval_density[:result]) if options[:analysis_result]
          json = Arel.json(fields)

          interval_density.project(json.json_agg.as(name.to_s))
        end

        def self.format_result(result, base_key = 'coverage', suffix: nil)
          key = suffix ? "#{base_key}_#{suffix}" : base_key
          Decode.row_with_tsrange result, key
        end
      end
    end
  end
end
