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

    def self.coverage_analysis
      Report::Ctes::Coverage::Coverage.new_with_suffix(:analysis, analysis_result: true)
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
      base_table.project(
        base_table[:site_id].distinct.array_agg.as('site_ids'),
        base_table[:region_id].distinct.array_agg.as('region_ids'),
        base_table[:tag_id].distinct.array_agg.as('tag_ids'),
        base_table[:audio_recording_id].distinct.array_agg.as('audio_recording_ids'),
        base_table[:provenance_id].distinct.array_agg.as('provenance_ids'),
        base_table[:audio_event_id].count(true).as('audio_event_count'),
        accumulation.project(accumulation[:accumulation_series]),
        composition.project(composition[:composition_series]),
        event_summary.project(event_summary[:event_summaries]),
        coverage.project(coverage[:coverage]),
        coverage_analysis.project(coverage_analysis[:coverage_analysis])
      )
    end

    def self.format_result(result)
      result_hash = result&.first
      return {} if result_hash.nil?

      accumulation_series = Report::Ctes::AggTagAccumulation.format_result(result_hash)
      {
        site_ids: Decode.array(result_hash['site_ids']),
        region_ids: Decode.array(result_hash['region_ids']),
        tag_ids: Decode.array(result_hash['tag_ids']),
        provenance_ids: Decode.array(result_hash['provenance_ids']),
        generated_date: DateTime.now,
        bucket_count: accumulation_series.length,
        audio_events_count: result_hash['audio_event_count'],
        audio_recording_ids: Decode.array(result_hash['audio_recording_ids']),
        event_summaries: Report::Ctes::EventSummary::EventSummary.format_result(result_hash),
        accumulation_series: accumulation_series,
        composition_series: Report::Ctes::EventComposition.format_result(result_hash),
        coverage_series: { recording: Report::Ctes::Coverage::Coverage.format_result(result_hash),
                           analysis: Report::Ctes::Coverage::Coverage.format_result(result_hash, suffix: 'analysis') }
      }
    end
  end
end
