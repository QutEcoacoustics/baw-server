# frozen_string_literal: true

module Report
  class AudioEventReport < Base
    include Report::ArelHelpers

    def build_query
      base_query_projected = @base_query.arel
        .project(attributes)
      base_query_joined = add_joins(base_query_projected)

      base_table = Arel::Table.new('base_table')
      base_cte = Arel::Nodes::As.new(base_table, base_query_joined)

      time_series_config = TimeSeries::StartEndTime.call(@parameters)
      time_boundaries = TimeSeries.time_boundaries(
        time_series_config[:start_time],
        time_series_config[:end_time],
        time_series_config[:interval]
      )
      all_ctes = []
      all_ctes << base_cte
      all_ctes << time_boundaries.cte
      # time_boundaries => a Query object
      # time_boundaries.table => the time_boundaries Table
      # time_boundaries.cte => the CTE expression for time_boundaries

      # with
      bucket_count_case = case time_series_config[:interval]
                          when '1 month' then TimeSeries.expr_bucket_count_month
                          when '1 year' then TimeSeries.expr_bucket_count_year
                          else TimeSeries.expr_bucket_count_default
                          end

      # start_time: can be an expression that selects from a table
      # or an expression like string_as_timestamp_node
      min = Arel.sql('?::timestamp', Arel::Nodes.build_quoted(time_series_config[:start_time]))
      max = Arel.sql('?::timestamp', Arel::Nodes.build_quoted(time_series_config[:end_time]))

      calculated_settings = Arel::Table.new('calculated_settings')
      calculated_settings_query = Arel::SelectManager.new
        .project(bucket_count_case.as('bucket_count'),
          min.as('min_value'), max.as('max_value'))
      # time_boundaries.table[:report_start_time].as('min_value'),
      # time_boundaries.table[:report_end_time].as('max_value'))
      # .from(time_boundaries.table)

      calculated_settings_cte = Arel::Nodes::As.new(calculated_settings, calculated_settings_query)

      all_ctes << calculated_settings_cte

      all_buckets = Arel::Table.new('all_buckets')
      all_buckets_query = Arel::SelectManager.new
        .project(
          TimeSeries.generate_series(1, TimeSeries.select_ceiling_bucket_count).as('bucket_number'),
          TimeSeries.bucket_start_time.as('bucket_start_time'),
          TimeSeries.bucket_end_time.as('bucket_end_time')
        )
      all_buckets_cte = Arel::Nodes::As.new(all_buckets, all_buckets_query)
      all_ctes << all_buckets_cte

      data_with_buckets = Arel::Table.new('data_with_buckets')
      data_with_buckets_query = Arel::SelectManager.new
        .project([
          TimeSeries.width_bucket.as('bucket'),
          base_table[:tag_id]
        ])
        .from(base_table)

      data_with_buckets_cte = Arel::Nodes::As.new(data_with_buckets, data_with_buckets_query)
      all_ctes << data_with_buckets_cte

      first_appearances_case_when = Arel.sql(
        <<~SQL.squish
          CASE WHEN ROW_NUMBER() OVER (PARTITION BY tag_id ORDER BY bucket) = 1 THEN 1 ELSE 0 END
        SQL
      )

      first_appearances = Arel::Table.new('first_appearances')
      first_appearances_query = Arel::SelectManager.new
        .project(
          data_with_buckets[:bucket],
          first_appearances_case_when.as('is_first_time')
        )
        .from(data_with_buckets)
        .where(data_with_buckets[:bucket].eq(nil).invert)

      first_appearances_cte = Arel::Nodes::As.new(first_appearances, first_appearances_query)
      all_ctes << first_appearances_cte

      bucket_counts = Arel::Table.new('bucket_counts')
      bucket_counts_query = Arel::SelectManager.new
        .project(
          first_appearances[:bucket],
          first_appearances[:is_first_time].sum.as('new_unique_tags')
        )
        .from(first_appearances)
        .group(first_appearances[:bucket])

      bucket_counts_cte = Arel::Nodes::As.new(bucket_counts, bucket_counts_query)
      all_ctes << bucket_counts_cte

      window = Arel::Nodes::Window.new.order(all_buckets[:bucket_number])
      sum_unique_tags_over_window = bucket_counts[:new_unique_tags].sum.over(window)

      cumulative_unique_tags = Arel::Table.new('cumulative_unique_tags')
      cumulative_unique_tags_query = Arel::SelectManager.new
        # .with(all_ctes)
        .project(
          all_buckets[:bucket_number],
          all_buckets[:bucket_start_time],
          all_buckets[:bucket_end_time],
          # postgres 'tsrange' format output
          Arel.sql("tsrange(all_buckets . bucket_start_time, all_buckets . bucket_end_time, '(]') AS range"),

          sum_unique_tags_over_window.coalesce(0).cast('int').as('cumulative_unique_tagids_count')
        )
        .from(all_buckets)
        # outer join back to the main bucket series to get all bins as data points
        .join(bucket_counts, Arel::Nodes::OuterJoin)
        .on(all_buckets[:bucket_number].eq(bucket_counts[:bucket]))
        .order(all_buckets[:bucket_number].asc)

      cumulative_unique_tags_cte = Arel::Nodes::As.new(cumulative_unique_tags, cumulative_unique_tags_query)
      all_ctes << cumulative_unique_tags_cte

      aliased = cumulative_unique_tags.as('t')
      accum_subquery = Arel::SelectManager.new
        .project(aliased.right.row_to_json.json_agg)
        .from(aliased)

      event_summary_ctes, event_summaries_aggregate = event_summary_result(base_table)

      final = Arel::SelectManager.new
        .with(all_ctes + event_summary_ctes)
        .project(
          aggregate_distinct(base_table, :site_ids).as('site_ids'),
          aggregate_distinct(base_table, :region_ids).as('region_ids'),
          aggregate_distinct(base_table, :tag_id).as('tag_ids'),
          aggregate_distinct(base_table, :audio_recording_ids).as('audio_recording_ids'),
          aggregate_distinct(base_table, :provenance_id).as('provenance_ids'),
          base_table[:audio_event_id].count(distinct = true).as('audio_events_count'),
          accum_subquery.as('accumulation_series'),
          event_summaries_aggregate.as('event_summaries')
        )
        .from(base_table)

      debugger
      output = ActiveRecord::Base.connection.execute(final.to_sql)
      AudioEventReport.format(output)
    end

    # NOTE: spec didn't include a value for what type of consensus. it could be
    # consensus true or false or skipped etc. add this as a field?
    #
    # ==> things to be aware for the report output:
    # in the uncommon case, there can be more than one tagging for an event
    # the event_summaries are tag + audio_event (tagging) centric; each summary
    # datum for a tag has a count of events; an event associated with more than
    # one tag will be counted more than once. If you summed up each count field
    # across the event_summaries, the total should be equal to the length of
    # taggings, which can be greater than the count of audio_events.
    def event_summary_result(base_table)
      verification_base = verification_base_report_query(base_table)
      verification_counts = verification_counts_report_query(verification_base)
      verification_counts_per_tag_provenance_event = verification_counts_per_tag_provenance_event(verification_counts)
      verification_counts_per_tag_provenance = verification_counts_per_tag_provenance(verification_counts_per_tag_provenance_event)

      event_summaries = event_summaries_report_query(base_table, verification_counts_per_tag_provenance)
      event_summaries_aggregate = event_summaries_aggreated_for_main_query(event_summaries)
      event_summary_ctes = [
        verification_base.cte,
        verification_counts.cte,
        verification_counts_per_tag_provenance_event.cte,
        verification_counts_per_tag_provenance.cte,
        event_summaries.cte
      ]

      [event_summary_ctes, event_summaries_aggregate]
    end

    def verification_base_report_query(base_table)
      verification_base_table = Arel::Table.new('verification_base')
      verification_base_query = manager
        .project(
          base_table[:audio_event_id],
          base_table[:tag_id],
          base_table[:provenance_id],
          base_table[:score],
          verifications[:id].as('verification_id'),
          verifications[:confirmed]
        )
        .from(base_table)
        .join(verifications, Arel::Nodes::OuterJoin)
        .on(base_table[:audio_event_id].eq(verifications[:audio_event_id])
        .and(base_table[:tag_id].eq(verifications[:tag_id])))

      verification_base_cte = Arel::Nodes::As.new(verification_base_table, verification_base_query)
      ReportQuery.new(verification_base_table, verification_base_cte)
    end

    # one row per tag/provenance/audio_event/'confirmed category'
    # e.g. with audio_event_id: 1, tag_id: 1, provenance_id: 1, verifications:
    # [confirmed: correct, confirmed: incorrect]
    #   => 2 rows produced
    # category_count is calculated as per grouping and would give tuples like:
    #   { confirmed: correct, category_count: 1 }
    #   { confirmed: incorrect, category_count: 1 }
    # ratio is the ratio of category_count to total_count, for each group
    #   { confirmed: correct, category_count: 1, total_count: 2, ratio: 0.5 }
    #   { confirmed: incorrect, category_count: 1, total_count: 2, ratio: 0.5 }
    def verification_counts_report_query(verification_base)
      verification_counts_table = Arel::Table.new('verification_counts')

      count_sum_over = verification_base.table[:verification_id].count.sum.over(Arel::Nodes::Window.new
      .partition(
        verification_base.table[:tag_id],
        verification_base.table[:provenance_id],
        verification_base.table[:audio_event_id]
      )).coalesce(0)

      count_sum_over_nullif = Arel::Nodes::NamedFunction.new(
        'NULLIF', [count_sum_over, Arel::Nodes.build_quoted(0)]
      )

      verification_counts_query = manager
        .project(
          verification_base.table[:tag_id],
          verification_base.table[:provenance_id],
          verification_base.table[:audio_event_id],
          verification_base.table[:confirmed],
          verification_base.table[:verification_id].count.as('category_count'),
          verification_base.table[:verification_id].count.coalesce(0).cast('float') / count_sum_over_nullif.as('ratio')
        )
        .from(verification_base.table)
        .group(
          verification_base.table[:tag_id],
          verification_base.table[:provenance_id],
          verification_base.table[:audio_event_id],
          verification_base.table[:confirmed]
        )

      verification_counts_cte = Arel::Nodes::As.new(verification_counts_table, verification_counts_query)
      ReportQuery.new(verification_counts_table, verification_counts_cte)
    end

    # select the maximum value of the ratio for each group: this is the
    # consensus value for an audio event
    def verification_counts_per_tag_provenance_event(verification_counts_per_tag_provenance_event_confirmed_category)
      verification_counts_per_tag_provenance_event_table = Arel::Table.new('verification_counts_per_tag_provenance_event')
      verification_counts_per_tag_provenance_event_query = manager
        .project(
          verification_counts_per_tag_provenance_event_confirmed_category.table[:tag_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:provenance_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:audio_event_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:ratio].maximum.as('consensus_for_event'),
          verification_counts_per_tag_provenance_event_confirmed_category.table[:category_count].sum.as('total_verifications_for_event')
        )
        .from(verification_counts_per_tag_provenance_event_confirmed_category.table)
        .group(
          verification_counts_per_tag_provenance_event_confirmed_category.table[:tag_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:provenance_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:audio_event_id]
        )

      verification_counts_per_tag_provenance_event_cte = Arel::Nodes::As.new(
        verification_counts_per_tag_provenance_event_table,
        verification_counts_per_tag_provenance_event_query
      )

      ReportQuery.new(
        verification_counts_per_tag_provenance_event_table,
        verification_counts_per_tag_provenance_event_cte
      )
    end

    def verification_counts_per_tag_provenance(verification_counts_per_tag_provenance_event)
      verification_counts_per_tag_provenance_table = Arel::Table.new('verification_counts_per_tag_provenance')
      verification_counts_per_tag_provenance_query = manager.project(
        verification_counts_per_tag_provenance_event.table[:tag_id],
        verification_counts_per_tag_provenance_event.table[:provenance_id],
        verification_counts_per_tag_provenance_event.table[:audio_event_id].count.as('count'),
        verification_counts_per_tag_provenance_event.table[:consensus_for_event].average.as('consensus'),
        verification_counts_per_tag_provenance_event.table[:total_verifications_for_event].sum.as('verifications')
      )
        .from(verification_counts_per_tag_provenance_event.table)
        .group(
          verification_counts_per_tag_provenance_event.table[:tag_id],
          verification_counts_per_tag_provenance_event.table[:provenance_id]
        )

      verification_counts_per_tag_provenance_cte = Arel::Nodes::As.new(
        verification_counts_per_tag_provenance_table,
        verification_counts_per_tag_provenance_query
      )
      ReportQuery.new(
        verification_counts_per_tag_provenance_table,
        verification_counts_per_tag_provenance_cte
      )
    end

    def event_summary_counts_and_consensus_as_json(source)
      json = json_build_object_from_hash({
        count: source.table[:count],
        verifications: source.table[:verifications],
        consensus: source.table[:consensus]
      })
      Arel::Nodes::NamedFunction.new(
        'json_agg', [json]
      )
    end

    def event_summaries_report_query(base_table, verification_counts_per_tag_provenance)
      events_json = event_summary_counts_and_consensus_as_json(verification_counts_per_tag_provenance)
      event_summaries_table = Arel::Table.new('event_summaries')
      event_summaries_query = manager
        .project(
          verification_counts_per_tag_provenance.table[:provenance_id],
          verification_counts_per_tag_provenance.table[:tag_id],
          events_json.as('events')
        )
        .from([verification_counts_per_tag_provenance.table])
        .group(verification_counts_per_tag_provenance.table[:tag_id], verification_counts_per_tag_provenance.table[:provenance_id])

      event_summaries_cte = Arel::Nodes::As.new(event_summaries_table, event_summaries_query)
      ReportQuery.new(event_summaries_table, event_summaries_cte)
    end

    def verification_counts_aggregated(verification_counts, verification_base)
      verification_counts_aliased = verification_counts.table.as('v')
      verification_counts_json = manager
        .project(verification_counts_aliased.right.row_to_json.json_agg)
        .from(verification_counts_aliased)
        .group(verification_base.table[:tag_id])
    end

    def event_summaries_aggreated_for_main_query(event_summaries)
      event_summaries_aliased = event_summaries.table.as('e')
      event_summaries_json = Arel::SelectManager.new
        .project(event_summaries_aliased.right.json_agg)
        .from(event_summaries_aliased)
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
    def verifications = Verification.arel_table

    # Default attributes for projection
    # @return [Array<Arel::Attributes>] the attributes to select
    def attributes
      [
        taggings[:id].as('tagging_ids'),
        sites[:id].as('site_ids'),
        regions[:id].as('region_ids'),
        tags[:id].as('tag_id'),
        audio_events[:audio_recording_id].as('audio_recording_ids'),
        audio_events[:provenance_id].as('provenance_ids'),
        audio_events[:score].as('score'),
        audio_events[:id].as('audio_event_id'),
        audio_recordings[:recorded_date],
        # verifications[:id].as('verification_id'),
        # audio event absolute start and end time
        Arel::Nodes::SqlLiteral.new(start_time_absolute_expression),
        Arel::Nodes::SqlLiteral.new(end_time_absolute_expression)
      ]
    end

    # Adds left joins to the query
    def add_joins(query)
      query
        .join(taggings)
        .on(audio_events[:id].eq(taggings[:audio_event_id]))
        .join(tags)
        .on(taggings[:tag_id].eq(tags[:id]))
        .join(regions, Arel::Nodes::OuterJoin)
        .on(regions[:id].eq(sites[:region_id]))
    end

    def start_time_absolute_expression
      'audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || \' seconds\' as interval) ' \
        'as start_time_absolute'
    end

    def end_time_absolute_expression
      'audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || \' seconds\' as interval) ' \
        'as end_time_absolute'
    end

    def format_results(results)
      format(results)
    end

    # tmep: class method format for interactive use during development
    def self.format(results)
      result = results[0]

      array_decoder = PG::TextDecoder::Array.new
      json_decoder = PG::TextDecoder::JSON.new

      decoded_event_summaries = json_decoder.decode(result['event_summaries'])
      event_summaries = decoded_event_summaries.map { |item| transform_event_summary(item) }

      decoded_accumulation_series = json_decoder.decode(result['accumulation_series'])
      accumulation_series = decoded_accumulation_series.map { |bucket|
        transform_bucket_tsrange(bucket, as_date_time: true)
      }

      {
        site_ids: array_decoder.decode(result['site_ids']).map(&:to_i),
        region_ids: array_decoder.decode(result['region_ids']).map(&:to_i),
        tag_ids: array_decoder.decode(result['tag_ids']).map(&:to_i),
        provenance_ids: array_decoder.decode(result['provenance_ids']).map(&:to_i),
        generated_date: DateTime.now,
        bucket_count: accumulation_series.length,
        audio_events_count: result['audio_events_count'],
        audio_recording_ids: array_decoder.decode(result['audio_recording_ids']).map(&:to_i),
        event_summaries: event_summaries,
        accumulation_series: accumulation_series
      }
    end

    # experiemntal
    def self.format_results_using_type_map(results)
      # Alternative method?
      # But array values are formatted as strings
      conn = ActiveRecord::Base.connection.raw_connection
      result = conn.exec(final.to_sql)

      type_map = PG::TypeMapByColumn.new([
        PG::TextDecoder::Array.new, # site_ids
        PG::TextDecoder::Array.new, # audio_recording_ids
        PG::TextDecoder::Array.new, # tag_ids
        PG::TextDecoder::Array.new, # provenance_ids
        PG::TextDecoder::JSON.new   # accumulation_series
      ])
      result.type_map = type_map
      parsed_row = result[0] # Already decoded
    end

    def self.transform_bucket_tsrange(bucket, as_date_time: false)
      matches = bucket['range'].match(/\("([^"]+)","([^"]+)"\]/)
      return bucket unless matches

      bucket['range'] = if as_date_time
                          [DateTime.parse(matches[1]), DateTime.parse(matches[2])]
                        else
                          [matches[1], matches[2]]
                        end

      bucket
    end

    # extract the events object from the array unneccesary array wrapper and
    # round consensus to 2 decimal places
    def self.transform_event_summary(item)
      events_data = item['events'].first

      events_data = events_data.merge('consensus' => events_data['consensus'].round(2)) if events_data['consensus']

      item.merge('events' => events_data)
    end

    # temp method for debugging
    def decode_postgres_json_generic(result)
      json_decoder = PG::TextDecoder::JSON.new
      array_decoder = PG::TextDecoder::Array.new

      decoded = {}
      result.first.each do |key, value|
        # p value.class
        decoded[key] = if value.is_a?(String) && value.start_with?('[')
                         json_decoder.decode(value)
                       else
                         array_decoder.decode(value)
                       end
      end
      decoded
    end
  end
end
