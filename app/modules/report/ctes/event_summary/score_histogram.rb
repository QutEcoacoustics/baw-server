# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      #
      # Generates a frequency distribution of event scores, for each (tag_id, provenance_id) pair
      #
      # Rows are allocated a bin id based on their score using the `width_bucket`
      # function, dividing the interval between `provenance_score_minimum` and
      # `provenance_score_maximum` into {SCORE_BINS} equal-width buckets.
      #
      #   With SCORE_BINS = 50, provenance score_minimum -1.0, score_maximum 1.0
      #     Bin width = (1 - (-1)) / 50 = 0.04
      #     score -0.96  => bin 1
      #     score  0.02  => bin 26, etc
      #
      # == query output
      #
      #  emits columns:
      #    tag_id (int)
      #    provenance_id (int)
      #    bin_id (int)          -- the bin id representing the score range
      #    bin_count (bigint)    -- the number of events in the bin
      #    group_count (numeric) -- the total number of events for the tag/provenance grouping
      #
      # @todo width_bucket is upper exclusive - is it possible for a score to equal the provenance maximum?
      class ScoreHistogram < Cte::NodeTemplate
        table_name :score_histogram
        dependencies base_table: Report::Ctes::BaseEventReport

        SCORE_BINS = 50

        select do
          # returns the bucket/bin id for a score
          width_bucket = Arel::Nodes::NamedFunction.new('width_bucket', [
            base_table[:score],
            base_table[:provenance_score_minimum],
            base_table[:provenance_score_maximum],
            SCORE_BINS
          ])

          window = Arel::Nodes::Window.new.partition(base_table[:tag_id], base_table[:provenance_id])

          base_table.project(
            base_table[:tag_id],
            base_table[:provenance_id],
            width_bucket.dup.as('bin_id'), # dup because 'as' mutates the object, and we need it again below
            base_table[:audio_event_id].count.as('bin_count'), # count of events in the bin for a given (tag_id, provenance_id) pair
            base_table[:audio_event_id].count.sum.over(window).as('group_count') # sum the 'bin_counts' for all bins of that (tag_id, provenance_id) pair.
          ).group(
            base_table[:tag_id],
            base_table[:provenance_id],
            width_bucket
          )
        end
      end
    end
  end
end
