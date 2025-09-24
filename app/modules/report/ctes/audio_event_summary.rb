# frozen_string_literal: true

module Report
  module Ctes
    # CTE node representing the audio events report
    #
    # audio_event_summary
    # ├── base_table
    # ├── tag_accumulation
    # │   └── bucket_cumulative_unique
    # │       ├── bucket_time_series - - - - - - - - - ─┐
    # │       │   └── bucket_count  - - - - - - - - ─┐  |
    # │       │       └── time_range_and_interval    |  |
    # │       └── bucket_sum_unique                  |  |
    # │           └── bucket_first_tag               |  |
    # │               └── bucket_allocate            |  |
    # │                   ├── bucket_count (ref) ---─┘  |
    # │                   └── base_table (ref)          |
    # ├── event_composition                             |
    # │   └── composition_series                        |
    # │       ├── bucket_time_series (ref) - - - - - - ─┘
    # │       ├── base_table (ref)
    # │       └── base_verification
    # │           └── base_table (ref)
    # ├── event_summary
    # │   └── event_summary_json
    # │       ├── event_summary_statistics
    # │       │   └── verification_consensus
    # │       │       └── verification_count
    # │       │           └── base_verification (ref)
    # │       └── bin_series_scores
    # │           ├── bin_series
    # │           │   └── base_table (ref)
    # │           └── score_bin_fractions
    # │               └── score_histogram
    # │                   └── base_table (ref)
    # ├── coverage
    # │   └── interval_density
    # │       ├── interval_coverage
    # │       │   └── categorise_intervals  - - - - - - ─┐
    # │       │       ├── sort_temporal_events           |
    # │       │       │   └── base_table (ref)           |
    # │       │       └── interval_gap_size              |
    # │       └── event_coverage                         |
    # │           └── track_event_changes                |
    # │               └── stacked_temporal_events        |
    # │                   └── categorise_intervals (ref)─┘
    # └── coverage_analysis
    #     └── interval_density_analysis
    #         ├── interval_coverage_analysis
    #         │   └── categorise_intervals_analysis
    #         │       ├── sort_temporal_events_analysis
    #         │       │   └── base_table_analysis
    #         │       └── interval_gap_size_analysis
    #         └── event_coverage_analysis
    #             └── track_event_changes_analysis
    #                 └── stacked_temporal_events_analysis
    #                     └── categorise_intervals_analysis (ref)
    class AudioEventSummary < Cte::NodeTemplate
      self.default_name = 'audio_event_report'

      options do
        {
          bucket_size: 'day',
          start_time: nil, # report start time
          end_time: nil, # report end time
          scaling_factor: 1920, # coverage scaling factor
          lower_field: :recorded_date, # coverage
          upper_field: :end_date # coverage
        }
      end

      coverage_analysis_template = Class.new(Report::Ctes::Coverage::Coverage) do
        self.default_suffix = 'analysis'
        self.default_options = default_options.merge(analysis_result: true)
      end

      self.default_dependencies = {
        base_table: Report::Ctes::BaseEventReport,
        accumulation: Report::Ctes::Accumulation::Accumulation,
        composition: Report::Ctes::EventComposition::EventComposition,
        event_summary: Report::Ctes::EventSummary::EventSummary,
        coverage: Report::Ctes::Coverage::Coverage,
        coverage_analysis: coverage_analysis_template
      }

      self.default_select = lambda {
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
      }

      def self.format_result(result)
        result_hash = result&.first
        return {} if result_hash.nil?

        # called separately so the result length can be used for `bucket_count`
        accumulation_series = Report::Ctes::Accumulation::Accumulation.format_result(result_hash)
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
          composition_series: Report::Ctes::EventComposition::EventComposition.format_result(result_hash),
          coverage_series: { recording: Report::Ctes::Coverage::Coverage.format_result(result_hash),
                             analysis: Report::Ctes::Coverage::Coverage.format_result(result_hash, suffix: 'analysis') }
        }
      end
    end
  end
end
