# frozen_string_literal: true

module Api
  module Reporting
    # Report template producing normalised tag detection rates over time buckets,
    # per site. For each site/bucket it reports how much audio was recorded and
    # analysed, which analysis jobs contributed, how many minutes were manually
    # reviewed, and per-tag detected minute counts split by tagging source.
    #
    # Implements #call(query) for use as a template in execute_report.
    class TagRate
      include CteHelper

      RECORDINGS               = Arel::Table.new(:filtered_recordings)
      ANALYSED_RECORDINGS      = Arel::Table.new(:analysed_recordings)
      RECORDINGS_BY_BUCKET     = Arel::Table.new(:recordings_by_bucket)
      BUCKET_RECORDING_MINUTES = Arel::Table.new(:bucket_recording_minutes)
      BUCKET_ANALYSIS_IDS      = Arel::Table.new(:bucket_analysis_ids)
      TAGGED_MINUTES           = Arel::Table.new(:tagged_minutes)
      TAGGED_MINUTE_BUCKETS    = Arel::Table.new(:tagged_minute_buckets)
      MANUAL_MINUTES           = Arel::Table.new(:manual_minutes)
      DETECTED_MINUTES         = Arel::Table.new(:detected_minutes)
      TAGS_BY_BUCKET           = Arel::Table.new(:tags_by_bucket)

      RECORDING_RANGE = 'recording_range'

      TAGGING_SOURCE_MANUAL = 'manual'
      TAGGING_SOURCE_ANALYSIS = 'analysis'

      SECONDS_PER_MINUTE = 60

      # @param options [Hash]
      # @option options [String] :bucket_size required
      def initialize(options = {})
        @bucketer = Bucketer.new(options)
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        # The canonical bucket series provides the [start, end) range for the
        # output. Recording minutes and tag results are inner joined so only
        # buckets containing a recording and at least one detection appear.
        Arel::SelectManager.new
          .with(*ctes(query:))
          .from(Bucketer::BUCKETS)
          .join(BUCKET_RECORDING_MINUTES)
          .on(BUCKET_RECORDING_MINUTES[:bucket].eq(bucket_start))
          .join(BUCKET_ANALYSIS_IDS, Arel::Nodes::OuterJoin)
          .on(join_on_bucket_and_site(BUCKET_ANALYSIS_IDS))
          .join(MANUAL_MINUTES, Arel::Nodes::OuterJoin)
          .on(join_on_bucket_and_site(MANUAL_MINUTES))
          .join(TAGS_BY_BUCKET)
          .on(join_on_bucket_and_site(TAGS_BY_BUCKET))
          .project(site_result)
          .group(BUCKET_RECORDING_MINUTES[:site_id])
          .order(BUCKET_RECORDING_MINUTES[:site_id])
      end

      private

      def ctes(query:)
        [
          cte(RECORDINGS, recordings_cte(query)),
          *@bucketer.bucket_ctes(source_table: RECORDINGS, source_columns: [
            RECORDINGS[RECORDING_RANGE].lower.minimum,
            RECORDINGS[RECORDING_RANGE].upper.maximum
          ]),
          cte(ANALYSED_RECORDINGS, analysed_recordings_cte),
          cte(RECORDINGS_BY_BUCKET, recordings_by_bucket_cte),
          cte(BUCKET_RECORDING_MINUTES, bucket_recording_minutes_cte),
          cte(BUCKET_ANALYSIS_IDS, bucket_analysis_ids_cte),
          cte(TAGGED_MINUTES, tagged_minutes_cte),
          cte(TAGGED_MINUTE_BUCKETS, tagged_minute_buckets_cte),
          cte(MANUAL_MINUTES, manual_minutes_cte),
          cte(DETECTED_MINUTES, detected_minutes_cte),
          cte(TAGS_BY_BUCKET, tags_by_bucket_cte)
        ]
      end

      # Ready, non-deleted recordings the user may read, as half-open [start, end)
      # time ranges. Distinct because project-site joins can duplicate recordings.
      def recordings_cte(query)
        query
          .except(:select, :order, :limit, :offset)
          .distinct
          .reselect(
            recording_range_arel.as(RECORDING_RANGE),
            AudioRecording.arel_table[:id].as('audio_recording_id'),
            AudioRecording.arel_table[:site_id].as('site_id')
          ).arel
      end

      # TODO: move to audio recording model?
      def recording_range_arel
        Arel.tsrange(AudioRecording.arel_table[:recorded_date], AudioRecording.arel_recorded_end_date)
      end

      # Distinct successful analysis job ids per recording.
      def analysed_recordings_cte
        aji = AnalysisJobsItem.arel_table

        distinct_job_ids = Arel::Nodes::NamedFunction.new('array_agg', [aji[:analysis_job_id]])
        distinct_job_ids.distinct = true

        aji
          .project(
            RECORDINGS[:audio_recording_id],
            distinct_job_ids.as('successful_analysis_job_ids')
          )
          .join(RECORDINGS).on(aji[:audio_recording_id].eq(RECORDINGS[:audio_recording_id]))
          .where(aji[:result].eq(AnalysisJobsItem::RESULT_SUCCESS))
          .group(RECORDINGS[:audio_recording_id])
      end

      # One row per bucket each recording overlaps. Buckets are calendar-aligned
      # (date_trunc), so the per-recording generate_series emits only the buckets
      # a recording touches rather than the whole series. recording_range is
      # intersected (*) with the bucket so a straddling recording's minutes land
      # in the correct bucket; the && overlap check drops the trailing empty
      # bucket when the inclusive generate_series stop lands on a boundary.
      def recordings_by_bucket_cte
        interval = @bucketer.options.interval_arel

        series = Arel.generate_series(
          Arel.date_trunc(@bucketer.options.bucket_size, RECORDINGS[RECORDING_RANGE].lower),
          RECORDINGS[RECORDING_RANGE].upper,
          interval
        ).as('bucket_start')
        bucket_start = series.right
        bucket = Arel.tsrange(bucket_start, Arel::Nodes::InfixOperation.new('+', bucket_start, interval))
        range_intersection = Arel::Nodes::InfixOperation.new('*', RECORDINGS[RECORDING_RANGE], bucket)

        RECORDINGS
          .project(
            bucket_start.as('bucket'),
            RECORDINGS[:audio_recording_id],
            RECORDINGS[:site_id],
            range_intersection.as(RECORDING_RANGE),
            ANALYSED_RECORDINGS[:audio_recording_id].is_not_null.as('has_successful_analysis'),
            ANALYSED_RECORDINGS[:successful_analysis_job_ids]
          )
          .join(ANALYSED_RECORDINGS, Arel::Nodes::OuterJoin)
          .on(ANALYSED_RECORDINGS[:audio_recording_id].eq(RECORDINGS[:audio_recording_id]))
          .join(Arel::Nodes::Lateral.new(series))
          .on(Arel.sql('true'))
          .where(Arel::Nodes::InfixOperation.new('&&', RECORDINGS[RECORDING_RANGE], bucket))
      end

      # Recorded and analysed minutes per site/bucket. Analysed minutes filter the
      # sum to recordings backed by a successful analysis job.
      def bucket_recording_minutes_cte
        RECORDINGS_BY_BUCKET
          .project(
            RECORDINGS_BY_BUCKET[:bucket],
            RECORDINGS_BY_BUCKET[:site_id],
            cumulative_minutes.as('cumulative_minutes'),
            cumulative_analysed_minutes.as('cumulative_analysed_minutes')
          )
          .group(RECORDINGS_BY_BUCKET[:bucket], RECORDINGS_BY_BUCKET[:site_id])
      end

      def bucket_duration_seconds
        # ! TODO: remove Subtraction.new when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Subtraction.new(
          RECORDINGS_BY_BUCKET[RECORDING_RANGE].upper,
          RECORDINGS_BY_BUCKET[RECORDING_RANGE].lower
        ).extract('epoch')
      end

      def cumulative_minutes
        # ! TODO: Division when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Division.new(bucket_duration_seconds.sum, SECONDS_PER_MINUTE).ceil
      end

      def cumulative_analysed_minutes
        analysed_seconds = Arel::Nodes::Filter.new(
          bucket_duration_seconds.sum,
          RECORDINGS_BY_BUCKET[:has_successful_analysis]
        )
        # ! TODO: Division when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Division.new(Arel.coalesce(analysed_seconds, 0), SECONDS_PER_MINUTE).ceil
      end

      # Distinct successful analysis ids per bucket. successful_analysis_job_ids is
      # null for recordings with no successful analysis; unnest drops those, and
      # the final output coalesces empty buckets to an empty array.
      def bucket_analysis_ids_cte
        unnested = Baw::Arel::Nodes::Unnest.new([RECORDINGS_BY_BUCKET[:successful_analysis_job_ids]]).as('analysis_id')
        analysis_id = unnested.right

        # array_agg(DISTINCT ... ORDER BY ...) FILTER (...) has no Arel helper.
        analysis_ids = Arel.sql(<<~SQL.squish)
          array_agg(DISTINCT #{analysis_id} ORDER BY #{analysis_id})
            FILTER (WHERE #{analysis_id} IS NOT NULL) AS "analysis_ids"
        SQL

        RECORDINGS_BY_BUCKET
          .project(
            RECORDINGS_BY_BUCKET[:bucket],
            RECORDINGS_BY_BUCKET[:site_id],
            analysis_ids
          )
          .join(Arel::Nodes::Lateral.new(unnested), Arel::Nodes::OuterJoin)
          .on(Arel.sql('true'))
          .group(RECORDINGS_BY_BUCKET[:bucket], RECORDINGS_BY_BUCKET[:site_id])
      end

      # Distinct tagged minutes per recording, classified as sourced from an
      # analysis job (import file linked to an analysis jobs item) or manual. The
      # tagged minute is the event start truncated to the minute.
      def tagged_minutes_cte
        events = AudioEvent.arel_table
        taggings = Tagging.arel_table
        import_files = AudioEventImportFile.arel_table

        # `offset 0` is an optimisation fence, not a logical necessity: it stops
        # the planner from flattening the subquery into the outer join, pinning a
        # per-recording nested-loop lookup on the audio_recording_id index.
        events_subquery = events
          .project(events[:id], events[:start_time_seconds], events[:audio_event_import_file_id])
          .where(events[:audio_recording_id].eq(RECORDINGS[:audio_recording_id]))
          .skip(0)
        events_alias = Arel::Nodes::TableAlias.new(events_subquery, 'audio_events')

        tagged_minute = Arel.date_trunc(
          'minute',
          Arel.grouping(RECORDINGS[RECORDING_RANGE].lower + events_alias[:start_time_seconds].seconds)
        )

        tagging_source = Arel::Nodes::Case.new
          .when(import_files[:analysis_jobs_item_id].eq(nil)).then(TAGGING_SOURCE_MANUAL)
          .else(TAGGING_SOURCE_ANALYSIS)

        RECORDINGS
          .project(
            RECORDINGS[:site_id],
            taggings[:tag_id],
            tagged_minute.as('tagged_minute'),
            tagging_source.as('tagging_source')
          )
          .join(Arel::Nodes::Lateral.new(events_alias))
          .on(Arel.sql('true'))
          .join(taggings)
          .on(taggings[:audio_event_id].eq(events_alias[:id]))
          .join(import_files, Arel::Nodes::OuterJoin)
          .on(import_files[:id].eq(events_alias[:audio_event_import_file_id]))
          .distinct
      end

      # Assign each tagged minute to its calendar-aligned bucket. This mirrors the
      # bucketer's date_trunc alignment so it needs no bucket series lookup.
      def tagged_minute_buckets_cte
        TAGGED_MINUTES
          .project(
            Arel.date_trunc(@bucketer.options.bucket_size, TAGGED_MINUTES[:tagged_minute]).as('bucket'),
            TAGGED_MINUTES[:site_id],
            TAGGED_MINUTES[:tag_id],
            TAGGED_MINUTES[:tagged_minute],
            TAGGED_MINUTES[:tagging_source]
          )
      end

      # Unique minutes with any manual event per bucket: limited proxy for effort spent reviewing audio manually
      def manual_minutes_cte
        TAGGED_MINUTE_BUCKETS
          .project(
            TAGGED_MINUTE_BUCKETS[:bucket],
            TAGGED_MINUTE_BUCKETS[:site_id],
            distinct_minute_count.as('manual_events_minutes')
          )
          .where(TAGGED_MINUTE_BUCKETS[:tagging_source].eq(TAGGING_SOURCE_MANUAL))
          .group(TAGGED_MINUTE_BUCKETS[:bucket], TAGGED_MINUTE_BUCKETS[:site_id])
      end

      # Per-tag, per-bucket detection counts split by tagging source, plus the
      # distinct combined minutes across both sources.
      def detected_minutes_cte
        TAGGED_MINUTE_BUCKETS
          .project(
            TAGGED_MINUTE_BUCKETS[:bucket],
            TAGGED_MINUTE_BUCKETS[:site_id],
            TAGGED_MINUTE_BUCKETS[:tag_id],
            minute_count_for_source(TAGGING_SOURCE_ANALYSIS).as('detected_analysis_minutes'),
            minute_count_for_source(TAGGING_SOURCE_MANUAL).as('detected_manual_minutes'),
            distinct_minute_count.as('detected_combined_minutes')
          )
          .group(
            TAGGED_MINUTE_BUCKETS[:bucket],
            TAGGED_MINUTE_BUCKETS[:site_id],
            TAGGED_MINUTE_BUCKETS[:tag_id]
          )
      end

      # count(*) FILTER (WHERE tagging_source = ...)
      def minute_count_for_source(source)
        Arel::Nodes::Filter.new(
          Arel.star.count,
          TAGGED_MINUTE_BUCKETS[:tagging_source].eq(source)
        )
      end

      # count(DISTINCT (site_id, tagged_minute))
      def distinct_minute_count
        Arel::Nodes::Count.new(
          [Arel.grouping([TAGGED_MINUTE_BUCKETS[:site_id], TAGGED_MINUTE_BUCKETS[:tagged_minute]])],
          true
        )
      end

      # One tags array per site/bucket, ordered by tag_id.
      def tags_by_bucket_cte
        tag_object = Arel.json(
          tag_id: DETECTED_MINUTES[:tag_id],
          detected_analysis_minutes: DETECTED_MINUTES[:detected_analysis_minutes],
          detected_manual_minutes: DETECTED_MINUTES[:detected_manual_minutes],
          detected_combined_minutes: DETECTED_MINUTES[:detected_combined_minutes]
        )

        # jsonb_agg with ORDER BY has no Arel helper.
        tags = Arel.sql(<<~SQL.squish)
          jsonb_agg(#{tag_object.to_sql} ORDER BY #{DETECTED_MINUTES[:tag_id].to_sql}) AS "tags"
        SQL

        DETECTED_MINUTES
          .project(DETECTED_MINUTES[:bucket], DETECTED_MINUTES[:site_id], tags)
          .group(DETECTED_MINUTES[:bucket], DETECTED_MINUTES[:site_id])
      end

      # The lower bound of the canonical bucket, used to join and order buckets.
      def bucket_start
        Bucketer::BUCKETS[:bucket].lower
      end

      def join_on_bucket_and_site(table)
        table[:bucket].eq(bucket_start)
          .and(table[:site_id].eq(BUCKET_RECORDING_MINUTES[:site_id]))
      end

      # Final object per site, with one bucket object for each site/bucket
      # containing at least one tag result, ordered by bucket.
      def site_result
        bucket_object = Arel.json(
          bucket: [bucket_start, Bucketer::BUCKETS[:bucket].upper],
          cumulative_minutes: Arel.coalesce(BUCKET_RECORDING_MINUTES[:cumulative_minutes], 0),
          cumulative_analysed_minutes: Arel.coalesce(BUCKET_RECORDING_MINUTES[:cumulative_analysed_minutes], 0),
          manual_events_minutes: Arel.coalesce(MANUAL_MINUTES[:manual_events_minutes], 0),
          analysis_ids: Arel.coalesce(BUCKET_ANALYSIS_IDS[:analysis_ids], Arel.sql('array[]::integer[]')),
          tags: Arel.coalesce(TAGS_BY_BUCKET[:tags], Arel.sql("'[]'::jsonb"))
        )

        # jsonb_agg with ORDER BY has no Arel helper.
        Arel.sql(<<~SQL.squish)
          jsonb_build_object(
            'site', #{BUCKET_RECORDING_MINUTES[:site_id].to_sql},
            'buckets', jsonb_agg(#{bucket_object.to_sql} ORDER BY #{bucket_start.to_sql})
          ) AS "site_result"
        SQL
      end
    end
  end
end
