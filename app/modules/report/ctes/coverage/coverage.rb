# frozen_string_literal: true

module Report
  module Ctes
    module Coverage
      # returns a CTE with a field named using the table_name at evaluation time
      class Coverage < Report::Cte::NodeTemplate
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
