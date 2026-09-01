# frozen_string_literal: true

module Api
  module Reporting
    class TagRate
      include CteHelper

      RECORDINGS = Arel::Table.new(:filtered_recordings)
      RECORDING_RANGE = 'recording_range'
      # Bucketer::BUCKETS
      # Bucketer::BOUNDS

      def initialize(options = {})
        @bucketer = Bucketer.new(options)
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        recordings_cte = query
          .except(:select, :order, :limit, :offset)
          .reselect(
            recording_range_arel.as(RECORDING_RANGE),
            AudioRecording.arel_table[:id].as('audio_recording_id'),
            AudioRecording.arel_table[:site_id].as('site_id')
          ).arel

        analysed_recordings = Arel::Table.new(:analysed_recordings)
        aji = AnalysisJobsItem.arel_table

        distinct_ajis = Arel.sql(
          <<~SQL.squish
            array_agg(
              DISTINCT #{aji[:analysis_job_id].to_sql}
             ) AS "successful_analysis_job_ids"
          SQL
        )

        analysed_recordings_cte = aji
          .project(RECORDINGS[:audio_recording_id],
            distinct_ajis)
          .join(RECORDINGS).on(aji[:audio_recording_id].eq(RECORDINGS[:audio_recording_id]))
          .where(aji[:result].eq('success'))
          .group(RECORDINGS[:audio_recording_id])

        debugger

        recordings_by_bucket = Arel::Table.new(:recordings_by_bucket)

        # Generate only the buckets needed to cover each recording_range.
        # In most cases this generates one row per recording.
        bucket_series = Arel.generate_series(
          Arel.date_trunc(@bucketer.options.bucket_size, RECORDINGS[RECORDING_RANGE].lower),
          RECORDINGS[RECORDING_RANGE].upper,
          @bucketer.options.interval_arel
        ).as('bucket_series')

        bucket_start = bucket_series.right

        bucket = Arel.tsrange(bucket_start,
          Arel.sql("#{bucket_series.right} + #{@bucketer.options.interval_arel.to_sql}"))

        range_intersection = Arel::Nodes::InfixOperation.new('*', RECORDINGS[RECORDING_RANGE], bucket)

        recordings_by_bucket_cte = RECORDINGS
          .project(bucket_start.as('bucket'),
            RECORDINGS[:audio_recording_id],
            RECORDINGS[:site_id],
            range_intersection.as('recording_range'),
            analysed_recordings[:audio_recording_id].not_eq(nil).as('has_successful_analysis'),
            analysed_recordings[:successful_analysis_job_ids])
          .join(analysed_recordings, Arel::Nodes::OuterJoin).on(analysed_recordings[:audio_recording_id].eq(RECORDINGS[:audio_recording_id]))
          .join(Arel::Nodes::Lateral.new(bucket_series)).on(Arel.sql('true'))
          .where(RECORDINGS[RECORDING_RANGE].overlaps(bucket))

        recordings_by_bucket.project(Arel.star)
          .with([
            cte(RECORDINGS, recordings_cte),
            *@bucketer.bucket_ctes(source_table: RECORDINGS, source_columns: [
              RECORDINGS[RECORDING_RANGE].lower.minimum,
              RECORDINGS[RECORDING_RANGE].upper.maximum
            ]),
            cte(analysed_recordings, analysed_recordings_cte),
            cte(recordings_by_bucket, recordings_by_bucket_cte)
          ])
      end

      def ctes(query:)
        [
          cte(RECORDINGS, recordings_cte(query)),
          *@bucketer.bucket_ctes(source_table: RECORDINGS, source_columns: [
            RECORDINGS[RECORDING_RANGE].lower.minimum,
            RECORDINGS[RECORDING_RANGE].upper.maximum
          ])
        ]
      end

      def recordings_cte(query)
        query
          .except(:select, :order, :limit, :offset)
          .reselect(
            recording_range_arel.as(RECORDING_RANGE),
            AudioRecording.arel_table[:id].as('audio_recording_id')
          ).arel
      end

      # TODO: move to audio recording model?
      def recording_range_arel
        Arel.tsrange(AudioRecording.arel_table[:recorded_date], AudioRecording.arel_recorded_end_date)
      end
    end
  end
end
