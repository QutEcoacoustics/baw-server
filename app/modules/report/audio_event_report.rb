# frozen_string_literal: true

module Report
  # I think these report classes won't be needed as the new appraoch is
  # progressed? And the logic for a report configuration can move to the
  # report's controller. So this is inbetween the old and new approach.
  class AudioEventReport < Base
    include Report::ArelHelpers

    BASE_TABLE = Arel::Table.new('base_table')

    def build_query
      base_query_projected = @base_query.arel.project(attributes)
      base_query_joined = add_joins(base_query_projected)
      base_table = Arel::Table.new('base_table')
      base_cte = Arel::Nodes::As.new(base_table, base_query_joined)

      time_series_options = TimeSeries::Options.call(@parameters, base_table: BASE_TABLE)
      composition_options = {
        bucketed_time_series: Section::Accumulation::TABLE_BUCKETED_TIME_SERIES,
        base_table: BASE_TABLE,
        base_verification: Section::EventSummary::TABLE_VERIFICATION_BASE
      }
      recording_coverage_options = Report::Section::Coverage.options(time_series_options) { |opt|
        opt[:source] = base_table
        opt[:lower_field] = base_table[:recorded_date]
        opt[:upper_field] = Report::ArelHelpers.arel_recorded_end_date(base_table) # using AudioRecording.arel_recorded_end_date => missing FROM-clause entry for table "audio_recordings"
        opt[:analysis_result] = false
        opt[:project_field_as] = 'recording'
      }

      analysis_options = { analysis_result: true, project_field_as: 'analysis', suffix: '_analysis' }
      analysis_coverage_options = recording_coverage_options.merge(analysis_options)

      # need some kind of api for hiding the mess below
      audio_event_report = [
        [Report::Section::Accumulation, time_series_options],
        [Report::Section::EventSummary, time_series_options],
        [Report::Section::Composition, composition_options],
        [Report::Section::Coverage, recording_coverage_options],
        [Report::Section::Coverage, analysis_coverage_options]
      ]

      results = audio_event_report
        .map { |section, opts| section.process(options: opts) }

      # yuk
      accumulation_series_aggregate,
      event_summaries_aggregate,
      composition_series_aggregate,
      recording_coverage_aggregate,
      analysis_coverage_aggregate = audio_event_report.zip(results)
        .map { |(section, opts), result|
        section.project(result, opts)
      }

      Report::TableExpression::Collection.new.then { |collection|
        results.reduce(collection) { |collection, result|
          Report::Section.transform_to_collection(result, collection)
        }
      }.ctes => all_ctes

      all_ctes.prepend(base_cte)

      Arel::SelectManager.new
        .with(all_ctes)
        .project(
          aggregate_distinct(base_table, :site_ids).as('site_ids'),
          aggregate_distinct(base_table, :region_ids).as('region_ids'),
          aggregate_distinct(base_table, :tag_id).as('tag_ids'),
          aggregate_distinct(base_table, :audio_recording_id).as('audio_recording_ids'),
          aggregate_distinct(base_table, :provenance_id).as('provenance_ids'),
          base_table[:audio_event_id].count(distinct = true).as('audio_events_count'),
          accumulation_series_aggregate.as('accumulation_series'),
          event_summaries_aggregate.as('event_summaries'),
          composition_series_aggregate.as('composition_series'),
          analysis_coverage_aggregate,
          recording_coverage_aggregate
        )
        .from(base_table)
    end

    # @param filter_params [ActionController::Parameters] the filter parameters
    # @param base_scope [ActiveRecord::Relation] the base scope for the query
    def filter_as_relation(filter_params, base_scope)
      filter_query = Filter::Query.new(
        filter_params,
        base_scope,
        AudioEvent,
        AudioEvent.filter_settings
      )
      filter_query.query_without_paging_sorting
    end

    def audio_events = AudioEvent.arel_table
    def audio_recordings = AudioRecording.arel_table
    def sites = Site.arel_table
    def regions = Region.arel_table
    def tags = Tag.arel_table
    def taggings = Tagging.arel_table
    def provenance = Provenance.arel_table
    def analysis_jobs_items = AnalysisJobsItem.arel_table

    # Default attributes for projection
    # @return [Array<Arel::Attributes>] the attributes to select
    def attributes
      [
        taggings[:id].as('tagging_ids'),
        sites[:id].as('site_ids'),
        regions[:id].as('region_ids'),
        tags[:id].as('tag_id'),
        audio_events[:score].as('score'),
        audio_events[:id].as('audio_event_id'),
        audio_recordings[:recorded_date],
        audio_recordings[:duration_seconds],
        provenance[:score_minimum].as('provenance_score_minimum'),
        provenance[:score_maximum].as('provenance_score_maximum'),
        analysis_jobs_items[:result].as('result'),
        # audio event absolute start and end time
        Arel::Nodes::SqlLiteral.new(start_time_absolute_expression),
        Arel::Nodes::SqlLiteral.new(end_time_absolute_expression)
      ]
    end

    def add_joins(query)
      query
        .join(taggings)
        .on(audio_events[:id].eq(taggings[:audio_event_id]))
        .join(tags)
        .on(taggings[:tag_id].eq(tags[:id]))
        .join(regions, Arel::Nodes::OuterJoin)
        .on(regions[:id].eq(sites[:region_id]))
        .join(analysis_jobs_items, Arel::Nodes::OuterJoin)
        .on(analysis_jobs_items[:audio_recording_id].eq(audio_events[:audio_recording_id]))
        .join(provenance, Arel::Nodes::OuterJoin)
        .on(provenance[:id].eq(audio_events[:provenance_id]))
    end

    # returns an expression that projects the absolute start time of an audio
    # event as a derived columnn
    def start_time_absolute_expression
      'audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || \' seconds\' as interval) ' \
        'as start_time_absolute'
    end

    # returns an expression that projects the absolute end time of an audio
    # event as a derived columnn
    def end_time_absolute_expression
      'audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || \' seconds\' as interval) ' \
        'as end_time_absolute'
    end

    # temp: delegate to class method format for interactive use during development
    def format_results(results)
      AudioEventReport.format(results)
    end

    def self.format(results)
      result = results&.first
      return {} if result.nil?

      event_summaries = decode_json result['event_summaries'] do |item|
        transform_event_summary(item)
      end

      accumulation_series = decode_json result['accumulation_series'] do |item|
        AudioEventReport.transform_tsrange(item)
      end

      composition_series = decode_json result['composition_series'] do |item|
        AudioEventReport.transform_composition_series(item, AudioEventReport::COMPOSITION_OPTIONS)
      end

      coverage_analysis = decode_json result['analysis'] do |item|
        AudioEventReport.transform_tsrange(item)
      end

      coverage_recording = decode_json result['recording'] do |item|
        AudioEventReport.transform_tsrange(item)
      end

      {
        site_ids: decode_array(result['site_ids']),
        region_ids: decode_array(result['region_ids']),
        tag_ids: decode_array(result['tag_ids']),
        provenance_ids: decode_array(result['provenance_ids']),
        generated_date: DateTime.now,
        bucket_count: accumulation_series.length,
        audio_events_count: result['audio_events_count'],
        audio_recording_ids: decode_array(result['audio_recording_ids']),
        event_summaries: event_summaries,
        accumulation_series: accumulation_series,
        composition_series: composition_series,
        coverage_series: { recording: coverage_recording, analysis: coverage_analysis }
      }
    end

    def self.decode(row, decoder, &transform)
      decoded = decoder.decode(row)
      transform ? decoded.map(&transform) : decoded
    end

    def self.decode_array(row, &transform)
      default_block = proc { |x| x.to_i }
      decode(row, PG::TextDecoder::Array.new, &transform || default_block)
    end

    def self.decode_json(row, &)
      decode(row, PG::TextDecoder::JSON.new, &)
    end

    COMPOSITION_OPTIONS = {
      count_key: 'count',
      total_key: 'total_tags_in_bin',
      ratio_key: 'ratio',
      fields: ['range', 'tag_id', 'ratio'],
      events_hash_fields: ['count', 'verifications', 'consensus']
    }.freeze

    # post-processing to calculate the ratio of tag count to total tags in bin
    def self.transform_composition_series(item, opts)
      row = AudioEventReport.transform_tsrange(item)

      count = row.fetch(opts[:count_key], 0)
      total = row.fetch(opts[:total_key], 0)

      ratio = calculate_ratio(count, total)
      row_with_ratio = row.merge(opts[:ratio_key] => ratio)

      # structure the output to match our expected format
      base_fields = row_with_ratio.slice(*opts[:fields])
      events_data = row_with_ratio.slice(*opts[:events_hash_fields])
      base_fields.merge('events' => events_data)
    end

    def self.calculate_ratio(count, total)
      return 0.0 if total.zero?

      (count.to_f / total).round(2)
    end

    def self.transform_tsrange(row)
      matches = row['range'].match(/\["([^"]+)","([^"]+)"\)/)
      return row unless matches

      row['range'] = [DateTime.parse(matches[1]), DateTime.parse(matches[2])]
      row
    end

    # extract the events object from the length 1 array
    # and structure to match our expected format
    def self.transform_event_summary(item)
      events_data = item['events'].first
      events_data.merge!('consensus' => events_data['consensus'].round(3)) if events_data['consensus']

      item.merge('events' => events_data)
    end
  end
end
