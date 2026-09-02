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
      RECORDING_BUCKET_SLICES  = Arel::Table.new(:recording_bucket_slices)
      CUMULATIVE_MINUTES       = Arel::Table.new(:cumulative_minutes)
      DISTINCT_ANALYSIS_JOB_IDS = Arel::Table.new(:distinct_analysis_job_ids)
      TAGGED_EVENT_MINUTES = Arel::Table.new(:tagged_event_minutes)
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
        # Recording minutes and tag results are inner joined so only
        # buckets containing a recording and at least one detection appear.
        Bucketer::BUCKETS
          .project(CUMULATIVE_MINUTES[:site_id])
          .with(*ctes(query:))
          .join(CUMULATIVE_MINUTES).on(CUMULATIVE_MINUTES[:bucket].eq(Bucketer::BUCKETS[:bucket].lower))
          .join(DISTINCT_ANALYSIS_JOB_IDS, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(DISTINCT_ANALYSIS_JOB_IDS))
          .join(MANUAL_MINUTES, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(MANUAL_MINUTES))
          .join(TAGS_BY_BUCKET).on(join_on_bucket_and_site(TAGS_BY_BUCKET))
          .group(CUMULATIVE_MINUTES[:site_id]).order(CUMULATIVE_MINUTES[:site_id])
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
          *@bucketer.bucket_ctes(source_table: RECORDINGS,
            source_columns: [RECORDINGS[RECORDING_RANGE].lower.minimum, RECORDINGS[RECORDING_RANGE].upper.maximum]),
          cte(ANALYSED_RECORDINGS, analysed_recordings_cte),
          cte(RECORDING_BUCKET_SLICES, recording_bucket_slices_cte),
          cte(CUMULATIVE_MINUTES, cumulative_minutes_cte),
          cte(DISTINCT_ANALYSIS_JOB_IDS, distinct_analysis_job_ids_cte),
          cte(TAGGED_EVENT_MINUTES, tagged_event_minutes_cte),
          cte(TAGGED_MINUTE_BUCKETS, tagged_minute_buckets_cte),
          cte(MANUAL_MINUTES, manual_minutes_cte),
          cte(DETECTED_MINUTES, detected_minutes_cte),
          cte(TAGS_BY_BUCKET, tags_by_bucket_cte)
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
        ).as('bucket')

        lower = series.right

        # lower is an SqlLiteral (the series alias) so `+` would concatenate the string, so use an infix node.
        bucket = Arel.tsrange(lower, Arel::Nodes::InfixOperation.new('+', lower, interval))

        RECORDINGS
          .project(
            lower, RECORDINGS[:audio_recording_id], RECORDINGS[:site_id],
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
        r = RECORDING_BUCKET_SLICES
        r.project(r[:bucket], r[:site_id], cumulative_minutes.as('cumulative_minutes'),
          cumulative_analysed_minutes.as('cumulative_analysed_minutes'))
          .group(r[:bucket], r[:site_id])
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
      # analysis job (import file linked to an analysis jobs item) or manual. The
      # tagged minute is the event start truncated to the minute.
      def tagged_event_minutes_cte
        events = AudioEvent.arel_table
        taggings = Tagging.arel_table
        imports = AudioEventImportFile.arel_table

        # `offset 0` is an optimisation fence: it stops the planner flattening the subquery into the outer
        # join, pinning a per-recording nested-loop lookup on the audio_recording_id index.
        events_sub = events
          .project(events[:id], events[:start_time_seconds], events[:audio_event_import_file_id])
          .where(events[:audio_recording_id].eq(RECORDINGS[:audio_recording_id])).skip(0)

        ev = Arel::Nodes::TableAlias.new(events_sub, 'audio_events')

        start_at = RECORDINGS[RECORDING_RANGE].lower + ev[:start_time_seconds].seconds
        minute = Arel.date_trunc('minute', Arel.grouping(start_at))
        source = Arel::Nodes::Case.new
          .when(imports[:analysis_jobs_item_id].eq(nil))
          .then(TAGGING_SOURCE_MANUAL)
          .else(TAGGING_SOURCE_ANALYSIS)

        RECORDINGS
          .project(RECORDINGS[:site_id], taggings[:tag_id], minute.as('tagged_minute'), source.as('tagging_source'))
          .join(Arel::Nodes::Lateral.new(ev)).on(Arel.sql('true'))
          .join(taggings).on(taggings[:audio_event_id].eq(ev[:id]))
          .join(imports, Arel::Nodes::OuterJoin).on(imports[:id].eq(ev[:audio_event_import_file_id]))
          .distinct
      end

      # Assign each tagged minute to its calendar-aligned bucket. This mirrors the
      # bucketer's date_trunc alignment.
      def tagged_minute_buckets_cte
        t = TAGGED_EVENT_MINUTES
        t.project(
          Arel.date_trunc(@bucketer.options.bucket_size, t[:tagged_minute]).as('bucket'),
          t[:site_id], t[:tag_id], t[:tagged_minute], t[:tagging_source]
        )
      end

      # Unique minutes with any manual event per bucket: limited proxy for effort spent reviewing audio manually
      def manual_minutes_cte
        t = TAGGED_MINUTE_BUCKETS
        t.project(t[:bucket], t[:site_id], distinct_minute_count.as('manual_events_minutes'))
          .where(t[:tagging_source].eq(TAGGING_SOURCE_MANUAL))
          .group(t[:bucket], t[:site_id])
      end

      # Per-tag, per-bucket detection counts split by tagging source, plus the
      # distinct combined minutes across both sources.
      def detected_minutes_cte
        t = TAGGED_MINUTE_BUCKETS
        t.project(t[:bucket], t[:site_id], t[:tag_id],
          minute_count_for_source(TAGGING_SOURCE_ANALYSIS).as('detected_analysis_minutes'),
          minute_count_for_source(TAGGING_SOURCE_MANUAL).as('detected_manual_minutes'),
          distinct_minute_count.as('detected_combined_minutes'))
          .group(t[:bucket], t[:site_id], t[:tag_id])
      end

      # count(*) FILTER (WHERE tagging_source = ...)
      def minute_count_for_source(source)
        Arel.star.count.filter(TAGGED_MINUTE_BUCKETS[:tagging_source].eq(source))
      end

      # count(DISTINCT (site_id, tagged_minute))
      def distinct_minute_count
        Arel.grouping([TAGGED_MINUTE_BUCKETS[:site_id], TAGGED_MINUTE_BUCKETS[:tagged_minute]]).count(true)
      end

      # One tags array per site/bucket, ordered by tag_id.
      def tags_by_bucket_cte
        d = DETECTED_MINUTES
        obj = Arel.json(
          tag_id: d[:tag_id], detected_analysis_minutes: d[:detected_analysis_minutes],
          detected_manual_minutes: d[:detected_manual_minutes], detected_combined_minutes: d[:detected_combined_minutes]
        )
        tags = Arel.sql("jsonb_agg(#{obj.to_sql} ORDER BY #{d[:tag_id].to_sql}) AS \"tags\"")

        d.project(d[:bucket], d[:site_id], tags).group(d[:bucket], d[:site_id])
      end

      def join_on_bucket_and_site(table)
        table[:bucket].eq(Bucketer::BUCKETS[:bucket].lower).and(table[:site_id].eq(CUMULATIVE_MINUTES[:site_id]))
      end
    end
  end
end
