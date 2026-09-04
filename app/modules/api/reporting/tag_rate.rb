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

      RECORDINGS                = Arel::Table.new(:filtered_recordings)
      ANALYSED_RECORDINGS       = Arel::Table.new(:analysed_recordings)
      RECORDING_BUCKET_SLICES   = Arel::Table.new(:recording_bucket_slices)
      CUMULATIVE_MINUTES        = Arel::Table.new(:cumulative_minutes)
      DISTINCT_ANALYSIS_JOB_IDS = Arel::Table.new(:distinct_analysis_job_ids)
      TAGGED_EVENT_MINUTES      = Arel::Table.new(:tagged_event_minutes)
      MANUAL_MINUTES            = Arel::Table.new(:manual_minutes)
      DETECTED_MINUTES          = Arel::Table.new(:detected_minutes)
      BUCKETS_SITES             = Arel::Table.new(:buckets_sites)

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
        # Recording minutes and tag results are inner joined so only
        # buckets containing a recording and at least one detection appear.
        d = DETECTED_MINUTES

        tag_obj = Arel.json(
          tag_id: d[:tag_id],
          detected_analysis_minutes: d[:detected_analysis_minutes],
          detected_manual_minutes: d[:detected_manual_minutes],
          detected_combined_minutes: d[:detected_combined_minutes]
        )

        ordered_aggregate = Arel.jsonb_agg(tag_obj).order(d[:tag_id])

        filtered_aggregate = Arel::Nodes::Filter.new(
          ordered_aggregate,
          d[:tag_id].is_not_null
        )

        tags = Arel.coalesce(
          filtered_aggregate,
          Arel.sql("'[]'::jsonb")
        )

        BUCKETS_SITES
          .project(
            BUCKETS_SITES[:site_id],
            BUCKETS_SITES[:bucket].as('range'),
            tags.as('tags'),
            Arel.coalesce(DISTINCT_ANALYSIS_JOB_IDS[:analysis_ids], Arel.sql('array[]::integer[]')).as('analysis_ids'),
            CUMULATIVE_MINUTES[:cumulative_minutes],
            CUMULATIVE_MINUTES[:cumulative_analysed_minutes],
            Arel.coalesce(MANUAL_MINUTES[:manual_events_minutes], 0).as('manual_events_minutes')
          )
          .with(*ctes(query:))
          .join(DETECTED_MINUTES, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(DETECTED_MINUTES))
          .join(DISTINCT_ANALYSIS_JOB_IDS, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(DISTINCT_ANALYSIS_JOB_IDS))
          .join(CUMULATIVE_MINUTES, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(CUMULATIVE_MINUTES))
          .join(MANUAL_MINUTES, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(MANUAL_MINUTES))
          .group(
            BUCKETS_SITES[:site_id],
            BUCKETS_SITES[:bucket],
            DISTINCT_ANALYSIS_JOB_IDS[:analysis_ids],
            CUMULATIVE_MINUTES[:cumulative_minutes],
            CUMULATIVE_MINUTES[:cumulative_analysed_minutes],
            MANUAL_MINUTES[:manual_events_minutes]
          )
        # .join(CUMULATIVE_MINUTES).on(CUMULATIVE_MINUTES[:bucket].eq(Bucketer::BUCKETS[:bucket]))
        # .join(DISTINCT_ANALYSIS_JOB_IDS, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(DISTINCT_ANALYSIS_JOB_IDS))
        # .join(MANUAL_MINUTES, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(MANUAL_MINUTES))
        # .group(CUMULATIVE_MINUTES[:site_id]).order(CUMULATIVE_MINUTES[:site_id])
      end

      # JSON array of bucket result objects for final projection.
      # Each bucket contains summary statistics and an array of per-tag results.
      def buckets
        obj = Arel.json(
          bucket: [Bucketer::BUCKETS[:bucket].lower, Bucketer::BUCKETS[:bucket].upper],
          analysis_ids: Arel.coalesce(DISTINCT_ANALYSIS_JOB_IDS[:analysis_ids], Arel.sql('array[]::integer[]')),
          tags: Arel.coalesce(TAGS_BY_BUCKET[:tags], Arel.sql("'[]'::jsonb")),
          cumulative_minutes: Arel.coalesce(CUMULATIVE_MINUTES[:cumulative_minutes], 0),
          cumulative_analysed_minutes: Arel.coalesce(CUMULATIVE_MINUTES[:cumulative_analysed_minutes], 0),
          manual_events_minutes: Arel.coalesce(MANUAL_MINUTES[:manual_events_minutes], 0)
        )

        Arel.jsonb_agg(obj).order(Bucketer::BUCKETS[:bucket].lower)
      end

      private

      def ctes(query:)
        [
          cte(RECORDINGS, recordings_cte(query)),
          cte(ANALYSED_RECORDINGS, analysed_recordings_cte),
          cte(RECORDING_BUCKET_SLICES, recording_bucket_slices_cte),
          cte(CUMULATIVE_MINUTES, cumulative_minutes_cte),
          cte(DISTINCT_ANALYSIS_JOB_IDS, distinct_analysis_job_ids_cte),
          cte(TAGGED_EVENT_MINUTES, tagged_event_minutes_cte),
          cte(MANUAL_MINUTES, manual_minutes_cte),
          cte(DETECTED_MINUTES, detected_minutes_cte),
          cte(BUCKETS_SITES, buckets_sites_cte)
        ]
      end

      def recordings_cte(query)
        query
          .except(:select, :order, :limit, :offset)
          .reselect(AudioRecording.recording_range_arel.as(RECORDING_RANGE),
            AudioRecording.arel_table[:id].as('audio_recording_id'),
            AudioRecording.arel_table[:site_id].as('site_id'))
          .arel
      end

      # Distinct successful analysis job ids per recording.
      def analysed_recordings_cte
        aji = AnalysisJobsItem.arel_table
        job_ids = aji[:analysis_job_id].array_agg
        job_ids.distinct = true

        aji
          .project(RECORDINGS[:audio_recording_id], job_ids.as('successful_analysis_job_ids'))
          .join(RECORDINGS).on(aji[:audio_recording_id].eq(RECORDINGS[:audio_recording_id]))
          .where(aji[:result].eq(AnalysisJobsItem::RESULT_SUCCESS))
          .group(RECORDINGS[:audio_recording_id])
      end

      # Intersect each recording's range with the buckets it touches, to measure how much
      # audio was recorded per bucket. A lateral generate_series emits only the buckets a
      # recording spans (usually one), avoiding a full recordings-against-buckets overlap
      # join: roughly O(N) work instead of O(N*B). The && overlap check drops the trailing
      # empty bucket produced when the inclusive generate_series stop lands on a boundary.
      def recording_bucket_slices_cte
        interval = @bucketer.options.interval_arel
        series = Arel.generate_series(
          Arel.date_trunc(@bucketer.options.bucket_size, RECORDINGS[RECORDING_RANGE].lower),
          RECORDINGS[RECORDING_RANGE].upper,
          interval
        ).as('bucket_lower')

        lower = series.right

        # lower is an SqlLiteral (the series alias) so `+` would concatenate the string, so use an infix node.
        bucket = Arel.tsrange(lower, Arel::Nodes::InfixOperation.new('+', lower, interval))

        RECORDINGS
          .project(
            bucket.dup.as('bucket'), RECORDINGS[:audio_recording_id], RECORDINGS[:site_id],
            (RECORDINGS[RECORDING_RANGE] * bucket).as(RECORDING_RANGE),
            ANALYSED_RECORDINGS[:audio_recording_id].is_not_null.as('has_successful_analysis'),
            ANALYSED_RECORDINGS[:successful_analysis_job_ids]
          )
          .join(ANALYSED_RECORDINGS, Arel::Nodes::OuterJoin)
          .on(ANALYSED_RECORDINGS[:audio_recording_id].eq(RECORDINGS[:audio_recording_id]))
          .join(Arel::Nodes::Lateral.new(series)).on(Arel.sql('true'))
          .where(RECORDINGS[RECORDING_RANGE].overlaps(bucket))
      end

      # Recorded and analysed minutes per site/bucket. Analysed minutes filter the
      # sum to recordings backed by a successful analysis job.
      def cumulative_minutes_cte
        RECORDING_BUCKET_SLICES
          .project(
            RECORDING_BUCKET_SLICES[:bucket],
            RECORDING_BUCKET_SLICES[:site_id],
            cumulative_minutes.as('cumulative_minutes'),
            cumulative_analysed_minutes.as('cumulative_analysed_minutes')
          )
          .group(RECORDING_BUCKET_SLICES[:bucket], RECORDING_BUCKET_SLICES[:site_id])
      end

      def cumulative_minutes
        # ! TODO: Division when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Division.new(recording_range_seconds.sum, SECONDS_PER_MINUTE).ceil
      end

      def cumulative_analysed_minutes
        secs = recording_range_seconds.sum.filter(RECORDING_BUCKET_SLICES[:has_successful_analysis])
        # ! TODO: Division when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Division.new(Arel.coalesce(secs, 0), SECONDS_PER_MINUTE).ceil
      end

      def recording_range_seconds
        range = RECORDING_BUCKET_SLICES[RECORDING_RANGE]
        # ! TODO: remove Subtraction.new when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Subtraction.new(range.upper, range.lower).extract('epoch')
      end

      # Distinct successful analysis job IDs per bucket. successful_analysis_job_ids is
      # null for recordings with no successful analysis and unnest filters those out.
      def distinct_analysis_job_ids_cte
        r = RECORDING_BUCKET_SLICES
        unnested_ids_table = Arel::Table.new(:unnested_ids)[:unnested_ids]
        unnested_ids_node = Baw::Arel::Nodes::Unnest.new([r[:successful_analysis_job_ids]]).as(unnested_ids_table.name)

        successful_job_ids = unnested_ids_table.array_agg
        successful_job_ids.distinct = true

        r.project(r[:bucket], r[:site_id], successful_job_ids.filter(unnested_ids_table.is_not_null).as('analysis_ids'))
          .join(Arel::Nodes::Lateral.new(unnested_ids_node), Arel::Nodes::OuterJoin).on(Arel.sql('true'))
          .group(r[:bucket], r[:site_id])
      end

      # Distinct tagged minutes per recording, classified as sourced from an
      # analysis job (import file linked to an analysis jobs item) or manual:
      # outputs at most one row per site/tag/minute/source(analysis/manual)
      # combination.
      # The 'tagged event minute' is the event start truncated to the minute.
      def tagged_event_minutes_cte
        events = AudioEvent.arel_table
        taggings = Tagging.arel_table
        imports = AudioEventImportFile.arel_table

        # Use a lateral per-recording event lookup because filtered_recordings is small
        # and audio_events is large. Together with OFFSET 0, this preserves the
        # parameterized nested-loop plan that uses the audio_recording_id index. A
        # direct inner join is logically equivalent but was slower by ~10
        # seconds in the report benchmark.
        events_sub = events
          .project(events[:id], events[:start_time_seconds], events[:audio_event_import_file_id])
          .where(events[:audio_recording_id].eq(RECORDINGS[:audio_recording_id])).skip(0)
        events_sub_table = Arel::Nodes::TableAlias.new(events_sub, 'audio_events')

        event_start_at = RECORDINGS[RECORDING_RANGE].lower + events_sub_table[:start_time_seconds].seconds
        tagged_minute = Arel.date_trunc('minute', Arel.grouping(event_start_at))

        tagging_source = Arel::Nodes::Case.new
          .when(imports[:analysis_jobs_item_id].eq(nil))
          .then(TAGGING_SOURCE_MANUAL)
          .else(TAGGING_SOURCE_ANALYSIS)

        RECORDINGS
          .project(
            RECORDINGS[:site_id],
            taggings[:tag_id],
            tagged_minute.as('tagged_minute'),
            tagging_source.as('tagging_source')
          )
          .join(Arel::Nodes::Lateral.new(events_sub_table)).on(Arel.sql('true'))
          .join(taggings).on(taggings[:audio_event_id].eq(events_sub_table[:id]))
          .join(imports, Arel::Nodes::OuterJoin).on(imports[:id].eq(events_sub_table[:audio_event_import_file_id]))
          .distinct
      end

      # Unique minutes with any manual event per bucket: limited proxy for
      # effort spent reviewing audio manually
      def manual_minutes_cte
        TAGGED_EVENT_MINUTES.project(
          @bucketer.bucket(column: TAGGED_EVENT_MINUTES[:tagged_minute]).as('bucket'),
          distinct_minute_count.as('manual_events_minutes'),
          TAGGED_EVENT_MINUTES[:site_id]
        )
          .where(TAGGED_EVENT_MINUTES[:tagging_source].eq(TAGGING_SOURCE_MANUAL))
          .group(
            @bucketer.bucket(column: TAGGED_EVENT_MINUTES[:tagged_minute]),
            TAGGED_EVENT_MINUTES[:site_id]
          )
      end

      # Per-tag, per-bucket detection counts split by tagging source, plus the
      # 'normalised' detection count ('distinct_minute_count' - distinct minutes
      # with any detection).
      def detected_minutes_cte
        TAGGED_EVENT_MINUTES.project(
          @bucketer.bucket(column: TAGGED_EVENT_MINUTES[:tagged_minute]).as('bucket'),
          TAGGED_EVENT_MINUTES[:site_id], TAGGED_EVENT_MINUTES[:tag_id],
          minute_count_for_source(TAGGING_SOURCE_ANALYSIS).as('detected_analysis_minutes'),
          minute_count_for_source(TAGGING_SOURCE_MANUAL).as('detected_manual_minutes'),
          distinct_minute_count.as('detected_combined_minutes')
        )
          .group(
            @bucketer.bucket(column: TAGGED_EVENT_MINUTES[:tagged_minute]),
            TAGGED_EVENT_MINUTES[:site_id],
            TAGGED_EVENT_MINUTES[:tag_id]
          )
      end

      # want rows for all site/bucket combinations that have recordings, even if they have no tags.
      # because we want the information about the non-zero denominators - sites/buckets that have recordings, but no tags.
      # as a result, any omitted site/bucket combinations had no recordings.
      def buckets_sites_cte
        RECORDING_BUCKET_SLICES.project(
          RECORDING_BUCKET_SLICES[:bucket],
          RECORDING_BUCKET_SLICES[:site_id]
        ).distinct
      end

      # count(*) FILTER (WHERE tagging_source = ...)
      def minute_count_for_source(source)
        Arel.star.count.filter(TAGGED_EVENT_MINUTES[:tagging_source].eq(source))
      end

      # count(DISTINCT (site_id, tagged_minute))
      def distinct_minute_count
        Arel.grouping([TAGGED_EVENT_MINUTES[:site_id], TAGGED_EVENT_MINUTES[:tagged_minute]]).count(true)
      end

      def join_on_bucket_and_site(table)
        table[:bucket].eq(BUCKETS_SITES[:bucket]).and(table[:site_id].eq(BUCKETS_SITES[:site_id]))
      end
    end
  end
end
