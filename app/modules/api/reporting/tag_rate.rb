# frozen_string_literal: true

module Api
  module Reporting
    # Report template producing tag detection rates per site/bucket combinations.
    # For each site/bucket it reports how much audio was recorded and
    # analysed, which analysis jobs contributed, how many minutes were manually
    # reviewed, and per-tag detected minute counts split by tagging source.
    #
    # Site/bucket combinations with audio but no tags are included in the
    # results. These rows show recording effort relative to zero detections,
    # which is a meaningful result. Site/bucket combinations with no audio or
    # tags are omitted.
    #
    # Implements #call(query) for use as a template in execute_report.
    class TagRate
      include CteHelper

      RECORDINGS                = Arel::Table.new(:filtered_recordings)
      ANALYSED_RECORDINGS       = Arel::Table.new(:analysed_recordings)
      RECORDING_RANGE_SLICES    = Arel::Table.new(:recording_range_slices)
      TOTAL_MINUTES             = Arel::Table.new(:total_minutes)
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
        BUCKETS_SITES
          .project
          .with(*ctes(query:))
          .join(DETECTED_MINUTES, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(DETECTED_MINUTES))
          .join(DISTINCT_ANALYSIS_JOB_IDS, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(DISTINCT_ANALYSIS_JOB_IDS))
          .join(TOTAL_MINUTES, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(TOTAL_MINUTES))
          .join(MANUAL_MINUTES, Arel::Nodes::OuterJoin).on(join_on_bucket_and_site(MANUAL_MINUTES))
          .group(*site_bucket_summary_groups)
      end

      # Arel expression for a JSON array of tag detection count objects,
      # coalescing to an empty array for null tags.
      def tags_summary
        tag = Arel.json(
          tag_id: DETECTED_MINUTES[:tag_id],
          detected_analysis_minutes: DETECTED_MINUTES[:detected_analysis_minutes],
          detected_manual_minutes: DETECTED_MINUTES[:detected_manual_minutes],
          detected_combined_minutes: DETECTED_MINUTES[:detected_combined_minutes]
        )

        tags_ordered = Arel.jsonb_agg(tag).order(DETECTED_MINUTES[:tag_id])
        tags_ordered_not_null = Arel::Nodes::Filter.new(tags_ordered, DETECTED_MINUTES[:tag_id].is_not_null)

        Arel.coalesce(tags_ordered_not_null, Arel.sql("'[]'::jsonb"))
      end

      private

      def ctes(query:)
        [
          cte(RECORDINGS, recordings_cte(query)),
          cte(ANALYSED_RECORDINGS, analysed_recordings_cte),
          cte(RECORDING_RANGE_SLICES, recording_range_slices_cte),
          cte(TOTAL_MINUTES, total_minutes_cte),
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
          .reselect(
            AudioRecording.recording_range_arel.as(RECORDING_RANGE),
            AudioRecording.arel_table[:id].as('audio_recording_id'),
            AudioRecording.arel_table[:site_id]
          )
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
      # audio was recorded per bucket.
      #
      # A lateral generate_series emits only the buckets a recording spans
      # (usually one), avoiding a full recordings-against-buckets overlap join:
      # roughly O(N) work instead of O(N*B). The final overlap (&&) check drops the
      # trailing empty bucket produced when the inclusive generate_series stop
      # lands exactly on a bucket boundary.
      def recording_range_slices_cte
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

      # Return the total minutes of recorded and analysed audio per site/bucket.
      def total_minutes_cte
        RECORDING_RANGE_SLICES
          .project(
            RECORDING_RANGE_SLICES[:bucket],
            RECORDING_RANGE_SLICES[:site_id],
            total_minutes.as('total_minutes'),
            total_analysed_minutes.as('total_analysed_minutes')
          )
          .group(RECORDING_RANGE_SLICES[:bucket], RECORDING_RANGE_SLICES[:site_id])
      end

      # @return [Arel::Nodes::Division] total minutes of recorded audio (ceiled)
      def total_minutes
        # ! TODO: Division when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Division.new(recording_range_seconds.sum, SECONDS_PER_MINUTE).ceil
      end

      # @return [Arel::Nodes::Division] total minutes of analysed audio (ceiled)
      def total_analysed_minutes
        secs = recording_range_seconds.sum.filter(RECORDING_RANGE_SLICES[:has_successful_analysis])
        # ! TODO: Division when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Division.new(Arel.coalesce(secs, 0), SECONDS_PER_MINUTE).ceil
      end

      # The recording range in seconds. Note: this differs from recording
      # duration, since a recording's range may be split across buckets.
      # @return [Arel::Nodes::Subtraction] recording range in seconds
      def recording_range_seconds
        range = RECORDING_RANGE_SLICES[RECORDING_RANGE]
        # ! TODO: remove Subtraction.new when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Subtraction.new(range.upper, range.lower).extract('epoch')
      end

      # Distinct successful analysis job IDs per bucket. successful_analysis_job_ids is
      # null for recordings with no successful analysis and unnest filters those out.
      def distinct_analysis_job_ids_cte
        r = RECORDING_RANGE_SLICES
        unnested_ids_column = Arel::Table.new(:unnested_ids)[:unnested_ids]
        unnested_ids_node = Baw::Arel::Nodes::Unnest.new([r[:successful_analysis_job_ids]]).as(unnested_ids_column.name)

        successful_job_ids = unnested_ids_column.array_agg
        successful_job_ids.distinct = true

        r.project(r[:bucket], r[:site_id], successful_job_ids.filter(unnested_ids_column.is_not_null).as('analysis_ids'))
          .join(Arel::Nodes::Lateral.new(unnested_ids_node), Arel::Nodes::OuterJoin).on(Arel.sql('true'))
          .group(r[:bucket], r[:site_id])
      end

      # Distinct tagged minutes per recording, classified as sourced from an
      # analysis job (import file linked to an analysis jobs item) or manual.
      # Outputs at most one row per site/tag/minute/source(analysis/manual)
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
          .join(AnalysisJobsItem.arel_table, Arel::Nodes::OuterJoin)
          .on(AnalysisJobsItem.arel_table[:id].eq(imports[:analysis_jobs_item_id]))
          .where(
             imports[:analysis_jobs_item_id].eq(nil)
               .or(AnalysisJobsItem.arel_table[:result].eq(AnalysisJobsItem::RESULT_SUCCESS))
           )
          .distinct
      end

      # Unique minutes with any manual event per bucket. We use this to provide
      # a crude estimate of the manual tagging effort, since we don't have any
      # other way to measure this.
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

      # Detection counts: combined and split by tagging source.
      # Counts indicate the number of distinct minutes with at least one
      # event for that tag (per site/bucket).
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

      # Provides the unique site/bucket combinations to return in the final result.
      def buckets_sites_cte
        RECORDING_RANGE_SLICES.project(
          RECORDING_RANGE_SLICES[:bucket],
          RECORDING_RANGE_SLICES[:site_id]
        ).distinct
      end

      # count(*) FILTER (WHERE tagging_source = ...)
      def minute_count_for_source(source)
        Arel.star.count.filter(TAGGED_EVENT_MINUTES[:tagging_source].eq(source))
      end

      # count(DISTINCT (tagged_minute))
      def distinct_minute_count
        Arel.grouping([TAGGED_EVENT_MINUTES[:tagged_minute]]).count(true)
      end

      def join_on_bucket_and_site(table)
        table[:bucket].eq(BUCKETS_SITES[:bucket]).and(table[:site_id].eq(BUCKETS_SITES[:site_id]))
      end

      def site_bucket_summary_groups
        [
          BUCKETS_SITES[:site_id],
          BUCKETS_SITES[:bucket],
          DISTINCT_ANALYSIS_JOB_IDS[:analysis_ids],
          TOTAL_MINUTES[:total_minutes],
          TOTAL_MINUTES[:total_analysed_minutes],
          MANUAL_MINUTES[:manual_events_minutes]
        ]
      end
    end
  end
end
