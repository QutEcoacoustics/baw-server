# frozen_string_literal: true

module Report
  class AudioEvents < Report::Cte::Node
    include Report::Cte::Dsl

    table_name 'audio_event_report'

    default_options do
      {
        bucket_size: 'day',
        start_time: nil, # report start time
        end_time: nil, # report end time
        scaling_factor: 1920, # coverage scaling factor
        lower_field: :recorded_date, # coverage
        upper_field: :end_date # coverage
      }
    end

    # This isn't what I wanted. I would like a way to include a dependency
    # Class more than once, without having to make a new subclass for it. You
    # can achieve the same outcome by using the registry, but that would require
    # the caller of this node to initialise and inject the dependency node with
    # the options and suffix
    # With the current design, just initialising the dependency node as part
    # of this template would also not work, because when the AudioEvents report
    # is executed, that node and it's ancestors won't be initialised with the
    # request options.
    def self.coverage_analysis
      Report::Ctes::Coverage::Coverage.dup
        .tap { |dup| dup._suffix = :analysis }
        .tap { |dup| dup._select_block = dup._select_block.dup }
        .tap { |dup| dup._default_options = dup._default_options.merge(analysis_result: true) }
        .tap { |dup| dup._depends_on = dup._depends_on }.include(Report::Cte::ForceSuffix)
    end

    depends_on do
      {
        base_table: Report::Ctes::BaseEventReport,
        accumulation: Report::Ctes::AggTagAccumulation,
        composition: Report::Ctes::EventComposition,
        event_summary: Report::Ctes::EventSummary::EventSummary,
        coverage: Report::Ctes::Coverage::Coverage,
        coverage_analysis: coverage_analysis
      }
    end

    select do
      Arel::SelectManager.new.project(
        accumulation.project(accumulation[:accumulation_series]),
        composition.project(composition[:composition_series]),
        event_summary.project(event_summary[:event_summaries]),
        coverage.project(coverage[:coverage]),
        coverage_analysis.project(coverage_analysis[:coverage_analysis])
      )
    end

    def self.format_result(result)
      nil unless result.is_a?(PG::Result)
      result_hash = result.first
      { accumulation_series: Report::Ctes::AggTagAccumulation.format_result(result_hash) }
    end
  end
end
