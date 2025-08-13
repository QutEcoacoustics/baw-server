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

    # the problem is templating the same dependency more than once, without
    # having to make a new class for it, and without initialising the node
    # eagerly, meaning it won't get the initialize options from the request.
    # for now, something like this should work
    def self.coverage_analysis
      lambda { |opts|
        Report::Ctes::Coverage::Coverage.new(
          suffix: 'analysis',
          options: opts.merge(
            analysis_result: true
          )
        )
      }.call(options)
    end

    depends_on do
      {
        accumulation: Report::Ctes::AggTagAccumulation,
        composition: Report::Ctes::EventComposition,
        event_summary: Report::Ctes::EventSummary::EventSummary,
        coverage: Report::Ctes::Coverage::Coverage,
        coverage_analysis: -> { coverage_analysis }
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
  end
end
