# frozen_string_literal: true

module Api
  module Reporting
    # Report template with the required CTEs and joins to produce a report of
    # event summaries per groupings (tag, provenance). Includes event score
    # summary statistics, and a score histogram with event counts per bucket,
    # calculated as the relative position of the score between the histogram's
    # minimum and maximum score.
    #
    # Implements #call(query) for use as a template in execute_report.
    class EventSummaries
      include CteHelper

      EVENTS = Arel::Table.new(:filtered_events)
      STATS = Arel::Table.new(:stats)
      BIN_EVENTS = Arel::Table.new(:bin_events)
      BIN_COUNTS = Arel::Table.new(:bin_counts)
      BIN_SERIES = Arel::Table.new(:bin_series)
      COUNTS_SERIES = Arel::Table.new(:counts_series)

      NUMBER_OF_BINS = 50
      UNDERFLOW_BIN_INDEX = -1

      BUCKET_INDEX = :bucket_index
      HISTOGRAM_MINIMUM = :histogram_minimum
      HISTOGRAM_MAXIMUM = :histogram_maximum

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        query = query.joins(joins).left_outer_joins(:provenance)

        STATS
          .project(
            STATS[:tag_id],
            STATS[:provenance_id],
            STATS[:events]
          )
          .with(*ctes(query:))
          .join(COUNTS_SERIES, Arel::Nodes::OuterJoin)
          .on(group_join_condition(STATS, COUNTS_SERIES))
      end

      # Primary projection for an event summaries report
      #
      # Projects a json sub-object called `summary` containing score summary
      # statistics fields and histogram fields. In the case where a summary
      # shouldn't be shown (null provenance or all null scores), summary is set
      # to null. Necessary because of edge cases where a field has a value but
      # shouldn't be shown (e.g. a mean score when provenance is null). The
      # nested structure allows to conditionally show/hide the set of
      # conditional fields based on one conditional gate, instead of gating each
      # individual field, with no difference in query execution time.
      def event_summary
        Arel::Nodes::Case.new.when(summary_available).then(summary_json)
      end

      private

      def joins = { taggings: [:tag] }

      def ctes(query:)
        [
          cte(EVENTS, events_cte(query)),
          cte(STATS, stats_cte),
          cte(BIN_EVENTS, bin_events_cte),
          cte(BIN_COUNTS, bin_counts_cte),
          cte(BIN_SERIES, bin_series_cte),
          cte(COUNTS_SERIES, counts_series_cte)
        ]
      end

      def events_cte(query)
        query
          .except(:select, :order, :limit, :offset)
          .reselect(
            Tagging.arel_table[:tag_id].as('tag_id'),
            AudioEvent.arel_table[:provenance_id].as('provenance_id'),
            AudioEvent.arel_table[:score].as('score'),
            Provenance.arel_table[:score_minimum].as('prov_score_min'),
            Provenance.arel_table[:score_maximum].as('prov_score_max')
          ).arel
      end

      def stats_cte
        EVENTS
          .project(
            EVENTS[:tag_id],
            EVENTS[:provenance_id],
            Arel.star.count.as('events'),
            EVENTS[:score].minimum.as('score_minimum'),
            EVENTS[:score].maximum.as('score_maximum'),
            EVENTS[:score].average.as('score_mean'),
            EVENTS[:score].std.as('score_stddev'),
            *histogram_bounds_from_events
          ).group(
            *group_columns(EVENTS),
            EVENTS[:prov_score_min],
            EVENTS[:prov_score_max]
          )
      end

      # Assign event scores a bucket index
      def bin_events_cte
        EVENTS
          .project(
            EVENTS[:tag_id],
            EVENTS[:provenance_id],
            score_bucket_index.as(BUCKET_INDEX.to_s)
          )
          .join(STATS, Arel::Nodes::OuterJoin)
          .on(group_join_condition(EVENTS, STATS))
      end

      # Count the number of events in each bucket per group
      def bin_counts_cte
        BIN_EVENTS
          .project(
            Arel.star,
            BIN_EVENTS[BUCKET_INDEX].count
          )
          .group(*group_columns(BIN_EVENTS), BIN_EVENTS[BUCKET_INDEX])
      end

      # Generate NUMBER_OF_BINS + 2 indices for groups that can have a summary:
      # -1 (underflow), 0..NUMBER_OF_BINS-1 (in-range), NUMBER_OF_BINS (overflow)
      def bin_series_cte
        STATS
          .project(
            STATS[:tag_id],
            STATS[:provenance_id],
            Arel.generate_series(-1, NUMBER_OF_BINS, 1).as(BUCKET_INDEX.to_s)
          )
          .where(summary_available)
      end

      # Join the bin counts with the full series of bins to get a count for every bucket
      def counts_series_cte
        coalesce_count = Arel.coalesce(BIN_COUNTS[:count], 0)
        bucket_index_ascending = BIN_SERIES[BUCKET_INDEX].asc

        # jsonb_agg supports ORDER BY inline to guarantee element order in the output array
        scores_binned = Arel.sql(
          <<~SQL.squish
            jsonb_agg(
               #{coalesce_count.to_sql}
                ORDER BY #{bucket_index_ascending.to_sql}
             ) AS "scores_binned"
          SQL
        )

        BIN_SERIES
          .project(
            BIN_SERIES[:tag_id],
            BIN_SERIES[:provenance_id],
            scores_binned
          )
          .join(BIN_COUNTS, Arel::Nodes::OuterJoin)
          .on(group_join_condition(BIN_SERIES, BIN_COUNTS)
                .and(BIN_SERIES[BUCKET_INDEX].eq(BIN_COUNTS[BUCKET_INDEX])))
          .group(*group_columns(BIN_SERIES))
          .order(*group_columns(BIN_SERIES))
      end

      def group_columns(table) = [table[:tag_id], table[:provenance_id]]

      def group_join_condition(left, right)
        left[:tag_id].eq(right[:tag_id]).and(left[:provenance_id].eq(right[:provenance_id]))
      end

      # To scale the histogram, use the provenance's indicative minimum and
      # maximum if set, else fall back to the group's actual minimum and maximum score.
      def histogram_bounds_from_events
        [
          Arel.coalesce(EVENTS[:prov_score_min], EVENTS[:score].minimum).as(HISTOGRAM_MINIMUM.to_s),
          Arel.coalesce(EVENTS[:prov_score_max], EVENTS[:score].maximum).as(HISTOGRAM_MAXIMUM.to_s)
        ]
      end

      # Assigns each event score to one of NUMBER_OF_BINS buckets (with an inclusive
      # upper bound on the final bucket), or an underflow / overflow bucket.
      #
      # NOTE: Tried using BETWEEN + LEAST, but when all scores are equal (e.g. all 0.5)
      # the bucket formula divides by (max - min) = 0. Keeping score == maximum as its own
      # branch avoids the division-by-zero error.
      def score_bucket_index
        Arel::Nodes::Case.new
          .when(score_gteq_histogram_min.and(score_lt_histogram_max)).then(calculate_bucket_index)
          .when(score_eq_histogram_max).then(NUMBER_OF_BINS - 1)
          .when(score_lt_histogram_min).then(UNDERFLOW_BIN_INDEX)
          .when(score_gt_histogram_max).then(NUMBER_OF_BINS)
          .else(Arel.null)
      end

      def score_gteq_histogram_min = EVENTS[:score].gteq(STATS[HISTOGRAM_MINIMUM])
      def score_lt_histogram_max = EVENTS[:score].lt(STATS[HISTOGRAM_MAXIMUM])
      def score_eq_histogram_max = EVENTS[:score].eq(STATS[HISTOGRAM_MAXIMUM])
      def score_lt_histogram_min = EVENTS[:score].lt(STATS[HISTOGRAM_MINIMUM])
      def score_gt_histogram_max = EVENTS[:score].gt(STATS[HISTOGRAM_MAXIMUM])

      # Calculate the bucket index as the relative position of the score between
      # the histogram minimum and maximum, multiplied by the number of bins.
      def calculate_bucket_index
        # ! TODO: Division/Multiplcation when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        ratio = Arel::Nodes::Division.new(
          subtract_histogram_minimum(from: EVENTS[:score]),
          subtract_histogram_minimum(from: STATS[HISTOGRAM_MAXIMUM])
        )

        Arel::Nodes::Multiplication.new(ratio, NUMBER_OF_BINS).floor.cast('int')
      end

      # Translating the score range to start at 0 is necessary to handle negative scores
      def subtract_histogram_minimum(from:)
        # ! TODO: remove Subtraction.new when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel.grouping(Arel::Nodes::Subtraction.new(from, STATS[HISTOGRAM_MINIMUM]))
      end

      # Skip summary and histogram if no provenance or all scores are null
      # (score_minimum guards against zero-filled arrays from null-only groups)
      def summary_available
        STATS[:provenance_id].is_not_null.and(STATS[:score_minimum].is_not_null)
      end

      def summary_json
        Arel.json(
          **score_summary_statistics,
          **score_histogram
        )
      end

      def score_summary_statistics
        {
          score_minimum: STATS[:score_minimum],
          score_maximum: STATS[:score_maximum],
          score_mean: STATS[:score_mean],
          score_stddev: STATS[:score_stddev]
        }
      end

      def score_histogram
        {
          HISTOGRAM_MINIMUM => STATS[HISTOGRAM_MINIMUM],
          HISTOGRAM_MAXIMUM => STATS[HISTOGRAM_MAXIMUM],
          :histogram_bins => Arel.coalesce(COUNTS_SERIES[:scores_binned], Arel.sql("'[]'"))
        }
      end
    end
  end
end
