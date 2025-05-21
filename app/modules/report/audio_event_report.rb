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

      # the problem with this is that I can't easily re-use the intermediate
      # tables without indexing on the cte array and using `.left`
      accumulation_series_ctes, accumulation_series_aggregate = TimeSeries::Accumulation.accumulation_series_result(
        base_table, @parameters
      )

      debugger
      event_summary_ctes, event_summaries_aggregate = event_summary_result(base_table)

      # hack. access the table using .left
      bucketed_time_series = accumulation_series_ctes.find { _1.left.name == 'bucketed_time_series' }
      base_verification = event_summary_ctes.find { _1.left.name == 'verification_base' }

      composition_series = composition_series_aggregate(bucketed_time_series, base_table, base_verification)
      composition_series_aggregate = composition_series_aggregated_for_main_query(composition_series)

      # analysis coverage
      analysis_coverage_options = Report::TimeSeries::Coverage.coverage_options(
        source: base_table,
        fields: { lower_field: base_table[:recorded_date],
                  upper_field: Report::TimeSeries::Coverage.arel_recorded_end_date(base_table) },
        analysis_result: true,
        project_field_as: 'analysis'
      )

      analysis_coverage_cte_collection = Report::TimeSeries::Coverage.coverage_series(
        TimeSeries::StartEndTime.call(@parameters), analysis_coverage_options
      )

      analysis_coverage_aggregate = TimeSeries::Coverage.coverage_series_arel(
        analysis_coverage_cte_collection,
        analysis_coverage_options
      )
      analysis_coverage_ctes = analysis_coverage_cte_collection.ctes

      # audio recording coverage
      recording_coverage_options = Report::TimeSeries::Coverage.coverage_options(
        source: base_table,
        fields: { lower_field: base_table[:recorded_date],
                  upper_field: Report::TimeSeries::Coverage.arel_recorded_end_date(base_table) },
        analysis_result: false,
        project_field_as: 'recording'
      )

      recording_coverage_cte_collection = Report::TimeSeries::Coverage.coverage_series(
        TimeSeries::StartEndTime.call(@parameters), recording_coverage_options
      )

      recording_coverage_aggregate = TimeSeries::Coverage.coverage_series_arel(
        recording_coverage_cte_collection,
        recording_coverage_options
      )
      recording_coverage_ctes = recording_coverage_cte_collection.ctes

      all_ctes = [base_cte]
      all_ctes += accumulation_series_ctes + event_summary_ctes + [composition_series.cte]
      all_ctes += analysis_coverage_ctes + recording_coverage_ctes

      final = Arel::SelectManager.new
        .with(all_ctes)
        .project(
          aggregate_distinct(base_table, :site_ids).as('site_ids'),
          aggregate_distinct(base_table, :region_ids).as('region_ids'),
          aggregate_distinct(base_table, :tag_id).as('tag_ids'),
          aggregate_distinct(base_table, :audio_recording_ids).as('audio_recording_ids'),
          aggregate_distinct(base_table, :provenance_id).as('provenance_ids'),
          base_table[:audio_event_id].count(distinct = true).as('audio_events_count'),
          accumulation_series_aggregate.as('accumulation_series'),
          event_summaries_aggregate.as('event_summaries'),
          composition_series_aggregate.as('composition_series'),
          analysis_coverage_aggregate,
          recording_coverage_aggregate
        )
        .from(base_table)
      output = ActiveRecord::Base.connection.execute(final.to_sql)
      AudioEventReport.format(output)
    end

    def work_in_progress
      verification_base = verification_base_report_query(base_table)
      verification_counts = verification_counts_report_query(verification_base)
      verification_counts_per_tag_provenance_event = verification_counts_per_tag_provenance_event(verification_counts)
      verification_counts_per_tag_provenance = verification_counts_per_tag_provenance(verification_counts_per_tag_provenance_event)
      ctes = [
        base_cte,
        verification_base.cte,
        verification_counts.cte,
        verification_counts_per_tag_provenance_event.cte,
        verification_counts_per_tag_provenance.cte
      ]

      one = verification_counts_per_tag_provenance_event.table.project(Arel.star).with(ctes)
      jj ActiveRecord::Base.connection.execute(one.to_sql).to_a

      # this is the target table that should output the array
      two = verification_counts_per_tag_provenance.table.project(Arel.star).with(ctes)
      jj ActiveRecord::Base.connection.execute(two.to_sql).to_a

      ### branch to get the bins

      bin_ids = TimeSeries.generate_series(50).to_sql
      series_alias = Arel.sql('bin_id')

      bucket = <<~SQL.squish
        WIDTH_BUCKET(
          verification_counts.score, provenances.score_minimum, provenances.score_maximum, 50
          ) as bin_id
      SQL

      verification_counts.table[:audio_event_id].count
        .over(Arel::Nodes::Window.new.partition(
          verification_counts.table[:tag_id], verification_counts.table[:provenance_id]
        )).as('group_count')

      scores_binned = Arel::Table.new('scores_binned')
      # Arel::Nodes::As.new(
      # scored_binned,
      out = verification_counts.table
        .project(
          verification_counts.table[:tag_id],
          verification_counts.table[:provenance_id],
          verification_counts.table[:audio_event_id],
          bucket
        )
        .join(provenance, Arel::Nodes::OuterJoin)
        .on(verification_counts.table[:provenance_id].eq(provenance[:id]))
        .with(ctes)
      # )

      jj ActiveRecord::Base.connection.execute(out.to_sql).to_a
    end

    # ==> things to be aware for the report output: in the uncommon case, there
    # can be more than one tagging for an event; the event_summaries are tag +
    # audio_event (tagging) centric; each summary datum for a tag has a count of
    # events; an event associated with more than one tag will be counted more
    # than once. If you summed up each count field across the event_summaries,
    # the total should be equal to the length of taggings, which can be greater
    # than the count of audio_events.
    #
    # WIP missing the score bins series
    # event summaries are unique by providence_id as well although that can
    # change easily.
    def event_summary_result(base_table)
      verification_base = verification_base_report_query(base_table)
      verification_counts = verification_counts_report_query(verification_base)
      verification_counts_per_tag_provenance_event = verification_counts_per_tag_provenance_event(verification_counts)
      verification_counts_per_tag_provenance = verification_counts_per_tag_provenance(verification_counts_per_tag_provenance_event)

      event_summaries = event_summaries_report_query(verification_counts_per_tag_provenance)
      event_summaries_aggregate = event_summaries_aggregated_for_main_query(event_summaries)
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
        'NULLIF', [count_sum_over, Arel.quoted(0)]
      )

      verification_counts_query = manager
        .project(
          verification_base.table[:tag_id],
          verification_base.table[:provenance_id],
          verification_base.table[:audio_event_id],
          verification_base.table[:score],
          verification_base.table[:confirmed],
          verification_base.table[:verification_id].count.as('category_count'),
          verification_base.table[:verification_id].count.coalesce(0).cast('float') / count_sum_over_nullif.as('ratio')
        )
        .from(verification_base.table)
        .group(
          verification_base.table[:tag_id],
          verification_base.table[:provenance_id],
          verification_base.table[:audio_event_id],
          verification_base.table[:confirmed],
          verification_base.table[:score]
        )

      verification_counts_cte = Arel::Nodes::As.new(verification_counts_table, verification_counts_query)
      ReportQuery.new(verification_counts_table, verification_counts_cte)
    end

    # select the maximum value of the ratio for each group: this is the
    # consensus value for an audio event
    def verification_counts_per_tag_provenance_event(verification_counts_per_tag_provenance_event_confirmed_category)
      # first we want the score histogram data, by tag and provenance, and then
      # join it to the below query
      # join BINS on tag_id and provenance_id, selecting the score_histogram
      # data.json_agg
      # BINS is a table with rows for each bin value and tag_id and
      # provenance_id
      # bin values are the count of audio_event scores that fall within the bin
      # interval.
      # 1. left outer join to get provenance min and max
      # 2. width_bucket(socre, provenance_min, provenance_max, 50) as
      #    allocated_bucket
      # 3. generate_series(provenance_min, provenance_max, 50) as buckets
      # 4. left outer join generate_series with width_bucket
      verification_counts_per_tag_provenance_event_table = Arel::Table.new('verification_counts_per_tag_provenance_event')
      verification_counts_per_tag_provenance_event_query = manager
        .project(
          verification_counts_per_tag_provenance_event_confirmed_category.table[:tag_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:provenance_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:audio_event_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:score],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:ratio].maximum.as('consensus_for_event'),
          verification_counts_per_tag_provenance_event_confirmed_category.table[:category_count].sum.as('total_verifications_for_event')
        )
        .from(verification_counts_per_tag_provenance_event_confirmed_category.table)
        .group(
          verification_counts_per_tag_provenance_event_confirmed_category.table[:tag_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:provenance_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:audio_event_id],
          verification_counts_per_tag_provenance_event_confirmed_category.table[:score]
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

    def score_histogram_agg; end

    def verification_counts_per_tag_provenance(verification_counts_per_tag_provenance_event)
      verification_counts_per_tag_provenance_table = Arel::Table.new('verification_counts_per_tag_provenance')
      verification_counts_per_tag_provenance_query = manager.project(
        verification_counts_per_tag_provenance_event.table[:tag_id],
        verification_counts_per_tag_provenance_event.table[:provenance_id],
        verification_counts_per_tag_provenance_event.table[:audio_event_id].count.as('count'),
        verification_counts_per_tag_provenance_event.table[:score].average.as('score_mean'),
        verification_counts_per_tag_provenance_event.table[:score].minimum.as('score_min'),
        verification_counts_per_tag_provenance_event.table[:score].maximum.as('score_max'),
        verification_counts_per_tag_provenance_event.table[:score].std.as('score_stdev'),
        # score_histogram_agg.as('score_bins'),
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
      json = Arel.json({
        count: source.table[:count],
        verifications: source.table[:verifications],
        consensus: source.table[:consensus]
      }).group # => jsonb_agg(jsonb_build_object (...))
    end

    def score_histogram_as_json(source)
      json = Arel.json({
        bins: source.table[:score_bins],
        standard_deviation: source.table[:score_stdev],
        mean: source.table[:score_mean],
        min: source.table[:score_min],
        max: source.table[:score_max]
      }).group # => jsonb_agg(jsonb_build_object (...))
    end

    def event_summaries_report_query(verification_counts_per_tag_provenance)
      events_json = event_summary_counts_and_consensus_as_json(verification_counts_per_tag_provenance)
      scores_json = score_histogram_as_json(verification_counts_per_tag_provenance)

      event_summaries_table = Arel::Table.new('event_summaries')
      event_summaries_query = manager
        .project(
          verification_counts_per_tag_provenance.table[:provenance_id],
          verification_counts_per_tag_provenance.table[:tag_id],
          events_json.as('events'),
          score_histogram.as('score_histogram')
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

    def event_summaries_aggregated_for_main_query(event_summaries)
      event_summaries_aliased = event_summaries.table.as('e')
      event_summaries_json = Arel::SelectManager.new
        .project(event_summaries_aliased.right.json_agg)
        .from(event_summaries_aliased)
    end

    def verification_consensus_by_event_tag(base_verification_table)
      base_verification_window_audio_event_tag = Arel::Nodes::Window.new.partition(
        base_verification_table[:audio_event_id],
        base_verification_table[:tag_id]
      )
      base_verification_total_over_window = base_verification_table[:verification_id].count.sum.over(base_verification_window_audio_event_tag)
      base_verification_ratio = base_verification_table[:verification_id].count.cast('float') / base_verification_total_over_window

      # Per audio_event and tag_id and confirmed value, count the number of confirmed values (number of correct, incorrect etc)
      # Per audio_event and tag_id, count the total verifications
      # Per audio event and tag_id, get the ratio of count of confirmed value / total count
      # {"audio_event_id"=>10, "tag_id"=>4, "confirmed"=>"correct", "confirmed_count"=>1, "total_count"=>0.3e1, "ratio"=>0.3333333333333333},
      # {"audio_event_id"=>10, "tag_id"=>4, "confirmed"=>"incorrect", "confirmed_count"=>2, "total_count"=>0.3e1, "ratio"=>0.6666666666666666}
      subquery_one = base_verification_table
        .project(
          base_verification_table[:audio_event_id],
          base_verification_table[:tag_id],
          base_verification_table[:confirmed],
          base_verification_ratio.as('ratio')
        )
        .from(base_verification_table)
        .group(
          base_verification_table[:audio_event_id],
          base_verification_table[:tag_id],
          base_verification_table[:confirmed]
        )
        .where(base_verification_table[:confirmed].not_eq(nil))

      subquery_one_alias = Arel::Nodes::TableAlias.new(subquery_one, 'subquery_one')

      # could I consolidate the following two subqueries to average only the max
      # ratio values for each audio event, using some kind of distinct on (..),
      # average(distinct ratios) with order by ratio descending
      subquery_two = manager
        .project(
          subquery_one_alias[:audio_event_id],
          subquery_one_alias[:tag_id],
          subquery_one_alias[:confirmed],
          subquery_one_alias[:ratio],
          Arel::Nodes::SqlLiteral.new('ROW_NUMBER() OVER (PARTITION BY tag_id, audio_event_id ORDER BY ratio DESC)').as('row_number')
        ).from(subquery_one_alias)

      subquery_two_alias = Arel::Nodes::TableAlias.new(subquery_two, 'subquery_two')

      # average of the consensus ratios (the consensus ratio is the highest
      # ratio value for an audio_event/tag_id; row_number = 1) per audio_event
      # and tag_id
      # not discriminating by confirmed value for now
      subquery_three = manager.project(
        subquery_two_alias[:audio_event_id],
        subquery_two_alias[:tag_id],
        # subquery_two_alias[:confirmed],
        subquery_two_alias[:ratio].average.as('consensus')
      ).from(subquery_two_alias)
        .where(subquery_two_alias[:row_number].eq(1))
        .group(
          subquery_two_alias[:audio_event_id],
          subquery_two_alias[:tag_id],
          subquery_two_alias[:row_number]
        )

      subquery_three_alias = Arel::Nodes::TableAlias.new(subquery_three, 'subquery_three')
    end

    # Time series aggregation across dimensions (time, tag_id) that counts
    # distinct audio events and verifications per group. Expect nrows to be
    # equal to the number of tags * number of buckets.
    def composition_series_aggregate(bucketed_time_series, base_table, base_verification)
      base_verification_table = base_verification.left
      consensus_ratios = verification_consensus_by_event_tag(base_verification_table)

      distinct_tags_table = Arel::Table.new('distinct_tags')
      distinct_tags_sql = Arel::Nodes::SqlLiteral.new('CROSS JOIN (SELECT DISTINCT tag_id FROM base_table) distinct_tags')

      window = Arel::Nodes::Window.new.partition(bucketed_time_series.left[:bucket_number])
      window_bucket_count = base_table[:audio_event_id].count(distinct = true).sum.over(window)

      select = manager
        .project(
          bucketed_time_series.left[:bucket_number],
          bucketed_time_series.left[:time_bucket].as('range'),
          Arel.sql('distinct_tags.tag_id'),
          base_table[:audio_event_id].count(distinct = true).as('count'), # count of events per tag per bucket
          window_bucket_count.as('total_tags_in_bin'),
          base_verification_table[:verification_id].count.as('verifications'),
          consensus_ratios[:consensus].as('consensus')
        )
        .from(bucketed_time_series.left)
        .join(distinct_tags_sql)
        .join(base_table, Arel::Nodes::OuterJoin)
        .on(bucketed_time_series.left[:time_bucket].contains(base_table[:start_time_absolute])
        .and(base_table[:tag_id].eq(distinct_tags_table[:tag_id])))
        .join(base_verification_table, Arel::Nodes::OuterJoin)
        .on(base_table[:audio_event_id].eq(base_verification_table[:audio_event_id])
        .and(base_table[:tag_id].eq(base_verification_table[:tag_id])))
        .join(consensus_ratios, Arel::Nodes::OuterJoin)
        .on(consensus_ratios[:audio_event_id].eq(base_verification_table[:audio_event_id])
        .and(consensus_ratios[:tag_id].eq(base_verification_table[:tag_id])))
        .group(
          bucketed_time_series.left[:bucket_number],
          bucketed_time_series.left[:time_bucket],
          distinct_tags_table[:tag_id],
          consensus_ratios[:consensus]
        )
        .order(distinct_tags_table[:tag_id], bucketed_time_series.left[:bucket_number])

      table = Arel::Table.new('composition_series')
      cte = Arel::Nodes::As.new(table, select)
      ReportQuery.new(table, cte)
    end

    def composition_series_aggregated_for_main_query(composition_series)
      composition_series_aliased = composition_series.table.as('c')
      composition_series_json = Arel::SelectManager.new
        .project(composition_series_aliased.right.json_agg)
        .from(composition_series_aliased)
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
    def analysis_jobs_items = AnalysisJobsItem.arel_table

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
        audio_recordings[:duration_seconds],
        provenance[:score_minimum].as('provenance_score_minimum'),
        provenance[:score_maximum].as('provenance_score_maximum'),
        # audio event absolute start and end time
        Arel::Nodes::SqlLiteral.new(start_time_absolute_expression),
        Arel::Nodes::SqlLiteral.new(end_time_absolute_expression),
        analysis_jobs_items[:result].as('result')
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

    # tmep: delegate to class method format for interactive use during development
    def format_results(results)
      AudioEventReport.format(results)
    end

    def self.format(results)
      result = results[0]

      array_decoder = PG::TextDecoder::Array.new
      json_decoder = PG::TextDecoder::JSON.new

      decoded_event_summaries = json_decoder.decode(result['event_summaries'])
      event_summaries = decoded_event_summaries.map { |item_name| transform_event_summary(item_name) }

      decoded_accumulation_series = json_decoder.decode(result['accumulation_series'])
      accumulation_series = decoded_accumulation_series.map { |row|
        AudioEventReport.transform_bucket_tsrange(row, as_date_time: true)
      }

      decoded_composition_series = json_decoder.decode(result['analysis'])
      composition_series = decoded_composition_series.map { |row|
        AudioEventReport.transform_composition_series(row, AudioEventReport.transform_composition_options).tap { |r|
          AudioEventReport.transform_bucket_tsrange(r, as_date_time: true)
        }
      }

      ['analysis', 'recording'].to_h do |key|
        decoded_coverage_series = json_decoder.decode(result[key])
        coverage_series = decoded_coverage_series.map { |row|
          AudioEventReport.transform_bucket_tsrange(row, as_date_time: true)
        }
        [key, coverage_series]
      end => coverage_series

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
        accumulation_series: accumulation_series,
        composition_series: composition_series,
        coverage_series: coverage_series
      }
    end

    def self.transform_composition_options
      {
        count_key: 'count',
        total_key: 'total_tags_in_bin',
        ratio_key: 'ratio',
        fields: ['range', 'tag_id', 'ratio'],
        events_hash_fields: ['count', 'verifications', 'consensus']
      }
    end

    def self.transform_composition_series(row, opts)
      count = row.fetch(opts[:count_key], 0)
      total = row.fetch(opts[:total_key], 0)
      ratio = total.zero? ? 0.to_f : (count.to_f / total).round(2)
      row_with_ratio = row.merge(opts[:ratio_key] => ratio)

      row_with_ratio.slice(*opts[:fields]).merge('events' => row_with_ratio.slice(*opts[:events_hash_fields]))
    end

    # experiemntal not in use
    def self.format_results_using_type_map(_results)
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

    def self.transform_bucket_tsrange(row, as_date_time: false)
      matches = row['range'].match(/\["([^"]+)","([^"]+)"\)/)
      return row unless matches

      row['range'] = if as_date_time
                       [DateTime.parse(matches[1]), DateTime.parse(matches[2])]
                     else
                       [matches[1], matches[2]]
                     end

      row
    end

    # extract the events object from the array unneccesary array wrapper and
    def self.transform_event_summary(item_name)
      events_data = item_name['events'].first

      events_data = events_data.merge('consensus' => events_data['consensus'].round(2)) if events_data['consensus']

      item_name.merge('events' => events_data)
    end

    # temp method for dev
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
