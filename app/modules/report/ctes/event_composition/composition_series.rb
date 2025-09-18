# frozen_string_literal: true

module Report
  module Ctes
    module EventComposition
      class CompositionSeries < Cte::NodeTemplate
        table_name :composition_series

        dependencies do
          { bucket_time_series: Accumulation::BucketTimeSeries,
            base_table: Report::Ctes::BaseEventReport,
            base_verification: Report::Ctes::BaseVerification }
        end

        select do
          # Subquery: consensus_ratios (Arel::Nodes::TableAlias)
          base_verification_window_audio_event_tag = Arel::Nodes::Window.new.partition(
            base_verification[:audio_event_id],
            base_verification[:tag_id]
          )
          base_verification_total_over_window = base_verification[:verification_id].count.sum.over(base_verification_window_audio_event_tag)
          base_verification_ratio = base_verification[:verification_id].count.cast('float') / base_verification_total_over_window

          # Subquery 1: From base_verification_table (one row per verification)
          #   For each unique audio_event, tag, and 'confirmed' value Get the
          #   count of verifications And the SUM of those counts over a window
          #   partitioned by audio_event and tag. This means: for a unique event +
          #   tag, how many verifications were there for each response type? And
          #   then divide that by how many in the event + tag in total. This gives
          #   you the ratio of each response type. The highest ratio is the
          #   consensus for that event + tag.
          subquery_one = base_verification
            .project(
              base_verification[:audio_event_id],
              base_verification[:tag_id],
              base_verification[:confirmed],
              base_verification_ratio.as('ratio')
            )
            .from(base_verification)
            .group(
              base_verification[:audio_event_id],
              base_verification[:tag_id],
              base_verification[:confirmed]
            )
            .where(base_verification[:confirmed].not_eq(nil))
          subquery_one_alias = Arel::Nodes::TableAlias.new(subquery_one, 'subquery_one')

          # and the maximum ratio is the consensus for that audio_event_id and
          # tag_id
          #
          # Notes about consensus: the consensus is the ratio of each response type
          # (e.g. correct, incorrect) to the total number of verifications for that
          # event + tag.
          #
          # When this is calculated, a ratio is given for each response type first.
          # The max value is chosen as the consensus.
          #
          # Then when joined to the composition series, we join by audio events and
          # tags, so they get placed in the right bucket, and the consensus is
          # averaged. So it's the average consensus for all audio events in the
          # bucket, for a tag.
          consensus_ratios = Arel::SelectManager.new
            .project(
              subquery_one_alias[:audio_event_id],
              subquery_one_alias[:tag_id],
              subquery_one_alias[:ratio].maximum.as('consensus')
            )
            .group(subquery_one_alias[:audio_event_id], subquery_one_alias[:tag_id])
            .from(subquery_one_alias)
          consensus_ratios_alias = Arel::Nodes::TableAlias.new(consensus_ratios, 'consensus_ratios')

          # Subquery: distinct_tags_sql (CROSS JOIN)
          distinct_tags_table = Arel::Table.new('distinct_tags')
          distinct_tags_sql = Arel::Nodes::SqlLiteral.new('CROSS JOIN (SELECT DISTINCT tag_id FROM base_table) distinct_tags')

          # Window for bucketed time series
          window = Arel::Nodes::Window.new.partition(bucket_time_series[:bucket_number])
          window_bucket_count = base_table[:audio_event_id].count(true).sum.over(window)

          # Main composition_series projection
          Arel::SelectManager.new
            .project(
              bucket_time_series[:bucket_number],
              bucket_time_series[:time_bucket].as('range'),
              Arel.sql('distinct_tags.tag_id'),
              base_table[:audio_event_id].count(true).as('count'), # count of events per tag per bucket
              window_bucket_count.as('total_tags_in_bin'),
              base_verification[:verification_id].count.as('verifications'),
              consensus_ratios_alias[:consensus].average.as('consensus')
            )
            .from(bucket_time_series)
            .join(distinct_tags_sql)
            .join(base_table, Arel::Nodes::OuterJoin)
            .on(bucket_time_series[:time_bucket].contains(base_table[:start_time_absolute])
              .and(base_table[:tag_id].eq(distinct_tags_table[:tag_id])))
            .join(base_verification, Arel::Nodes::OuterJoin)
            .on(base_table[:audio_event_id].eq(base_verification[:audio_event_id])
              .and(distinct_tags_table[:tag_id].eq(base_verification[:tag_id])))
            .join(consensus_ratios_alias, Arel::Nodes::OuterJoin)
            .on(consensus_ratios_alias[:audio_event_id].eq(base_table[:audio_event_id])
              .and(consensus_ratios_alias[:tag_id].eq(distinct_tags_table[:tag_id])))
            .group(
              bucket_time_series[:bucket_number],
              bucket_time_series[:time_bucket],
              Arel.sql('distinct_tags.tag_id')
            )
            .order(Arel.sql('distinct_tags.tag_id'), bucket_time_series[:bucket_number])
        end
      end
    end
  end
end
