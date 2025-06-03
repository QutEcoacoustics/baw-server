# frozen_string_literal: true

module Report
  module Section
    # This module defines a pipeline of Arel projections for summarising audio
    # events
    module EventSummary
      extend Report::Section

      module_function

      # Table constants for each step
      TABLE_VERIFICATION_BASE = Arel::Table.new('verification_base')
      TABLE_VERIFICATION_COUNTS = Arel::Table.new('verification_counts')
      TABLE_VERIFICATION_COUNTS_PER_EVENT = Arel::Table.new('verification_counts_per_tag_provenance_event')
      TABLE_VERIFICATION_COUNTS_PER_TAG_PROVENANCE = Arel::Table.new('verification_counts_per_tag_provenance')
      TABLE_SCORE_BINS = Arel::Table.new('score_bins')
      TABLE_SCORE_BIN_FRACTIONS = Arel::Table.new('score_bin_fractions')
      TABLE_BIN_SERIES = Arel::Table.new('bin_series')
      TABLE_BIN_SERIES_SCORES = Arel::Table.new('scores_all_bins')
      TABLE_EVENT_SUMMARIES = Arel::Table.new('event_summaries')

      TABLES = {
        verification_base: TABLE_VERIFICATION_BASE,
        verification_counts: TABLE_VERIFICATION_COUNTS,
        verification_counts_per_event: TABLE_VERIFICATION_COUNTS_PER_EVENT,
        verification_counts_per_tag_provenance: TABLE_VERIFICATION_COUNTS_PER_TAG_PROVENANCE,
        score_bins: TABLE_SCORE_BINS,
        score_bin_fractions: TABLE_SCORE_BIN_FRACTIONS,
        bin_series: TABLE_BIN_SERIES,
        bin_series_scores: TABLE_BIN_SERIES_SCORES,
        event_summaries: TABLE_EVENT_SUMMARIES
      }.freeze

      # @return [Integer] the number of score bins to use for histogram binning
      SCORE_BINS = 50

      step table: TABLE_VERIFICATION_BASE, as: proc { |_t, options|
        # Join base_table with verifications to get verification_id and
        base_table = options[:base_table]
        Arel::SelectManager.new.project(
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
      }

      # Count verifications per tag/provenance/audio_event/confirmed
      # Calculates category_count and ratio for each group
      step table: TABLE_VERIFICATION_COUNTS, depends_on: TABLE_VERIFICATION_BASE, as: proc { |_t, verification_base|
        # one row per tag/provenance/audio_event/'confirmed category'
        # category_count is calculated as per grouping and would give tuples like:
        #   { confirmed: correct, category_count: 1 }
        #   { confirmed: incorrect, category_count: 1 }
        # ratio is the ratio of category_count to total_count, for each group
        window = Arel::Nodes::Window.new.partition(
          verification_base[:tag_id],
          verification_base[:provenance_id],
          verification_base[:audio_event_id]
        )
        count_sum_over = verification_base[:verification_id].count.sum.over(window).coalesce(0)
        count_sum_over_nullif = Arel::Nodes::NamedFunction.new('NULLIF', [count_sum_over, Arel.quoted(0)])

        verification_base.project(
          verification_base[:tag_id],
          verification_base[:provenance_id],
          verification_base[:audio_event_id],
          verification_base[:score],
          verification_base[:confirmed],
          verification_base[:verification_id].count.as('category_count'),
          verification_base[:verification_id].count.coalesce(0).cast('float') / count_sum_over_nullif.as('ratio')
        ).group(
          verification_base[:tag_id],
          verification_base[:provenance_id],
          verification_base[:audio_event_id],
          verification_base[:confirmed],
          verification_base[:score]
        )
      }

      # Calculate consensus for each event
      # Selects the maximum value of the ratio for each group: this is the
      # consensus for a given audio event
      step table: TABLE_VERIFICATION_COUNTS_PER_EVENT, depends_on: TABLE_VERIFICATION_COUNTS, as: proc { |_t, verification_counts|
        # select the maximum value of the ratio for each group: this is the consensus value for an audio event
        verification_counts.project(
          verification_counts[:tag_id],
          verification_counts[:provenance_id],
          verification_counts[:audio_event_id],
          verification_counts[:score],
          verification_counts[:ratio].maximum.as('consensus_for_event'),
          verification_counts[:category_count].sum.as('total_verifications_for_event')
        ).group(
          verification_counts[:tag_id],
          verification_counts[:provenance_id],
          verification_counts[:audio_event_id],
          verification_counts[:score]
        )
      }

      # Aggregate event-level stats per tag/provenance
      # Produces count, score_mean, score_min, score_max, score_stdev, consensus, verifications
      step table: TABLE_VERIFICATION_COUNTS_PER_TAG_PROVENANCE, depends_on: TABLE_VERIFICATION_COUNTS_PER_EVENT, as: proc { |_t, verification_counts_per_event|
        verification_counts_per_event.project(
          verification_counts_per_event[:tag_id],
          verification_counts_per_event[:provenance_id],
          verification_counts_per_event[:audio_event_id].count.as('count'),
          verification_counts_per_event[:score].average.as('score_mean'),
          verification_counts_per_event[:score].minimum.as('score_min'),
          verification_counts_per_event[:score].maximum.as('score_max'),
          verification_counts_per_event[:score].std.as('score_stdev'),
          verification_counts_per_event[:consensus_for_event].average.as('consensus'),
          verification_counts_per_event[:total_verifications_for_event].sum.as('verifications')
        ).group(
          verification_counts_per_event[:tag_id],
          verification_counts_per_event[:provenance_id]
        )
      }

      # Score histogram binning steps
      # score_bins: Bin scores into 50 buckets for each tag/provenance
      # score_bin_fractions: Calculate fraction of scores in each bin
      # bin_series: Generate complete series of bins for each tag/provenance (CROSS JOIN)
      # bin_series_scores: Aggregate bin fractions into arrays
      step table: TABLE_SCORE_BINS, as: proc { |_t, options|
        # scores are binned into 50 buckets for unique tag/provenance
        base_table = options[:base_table]
        width_bucket = Arel::Nodes::NamedFunction.new('width_bucket', [
          base_table[:score],
          base_table[:provenance_score_minimum],
          base_table[:provenance_score_maximum],
          SCORE_BINS
        ])

        window = Arel::Nodes::Window.new.partition(
          base_table[:tag_id], base_table[:provenance_id]
        )

        base_table.project(
          base_table[:tag_id],
          base_table[:provenance_id],
          width_bucket.dup.as('bin_id'), # dup because 'as' mutates the object
          base_table[:audio_event_id].count.as('bin_count'),
          base_table[:audio_event_id].count.over(window).as('group_count')
        ).group(
          base_table[:tag_id],
          base_table[:provenance_id],
          base_table[:audio_event_id],
          width_bucket
        )
      }

      step table: TABLE_SCORE_BIN_FRACTIONS, depends_on: TABLE_SCORE_BINS, as: proc { |_t, score_bins|
        # calculate the fraction of scores in each bin, relative to the total for that tag/provenance group
        null_if_count = null_if(score_bins[:group_count], 0)
        score_bins.project(
          score_bins[:tag_id],
          score_bins[:provenance_id],
          score_bins[:bin_id],
          score_bins[:bin_count],
          score_bins[:group_count],
          (score_bins[:bin_count].cast('numeric') / null_if_count).round(3).as('bin_fraction')
        )
      }

      step table: TABLE_BIN_SERIES, as: proc { |_t, options|
        # get the complete series of bins 1 to 50 for unique tag_id and provenance_id
        base_table = options[:base_table]
        generate_series = Report::TimeSeries.generate_series(50).as('bin_id')
        cross_join = Arel::Nodes::StringJoin.new(Arel.sql('CROSS JOIN ?', generate_series))

        distinct_tag_provenance = base_table
          .project(base_table[:tag_id], base_table[:provenance_id])
          .distinct
          .as('distinct_tag_provenance')

        select = Arel::SelectManager.new.project(
          distinct_tag_provenance[:tag_id],
          distinct_tag_provenance[:provenance_id],
          generate_series.right
        ).from(distinct_tag_provenance)

        select.join_sources << cross_join
        select
      }

      step table: TABLE_BIN_SERIES_SCORES, depends_on: [TABLE_BIN_SERIES, TABLE_SCORE_BIN_FRACTIONS], as: proc { |_t, bin_series, score_bin_fractions|
        # aggregate bin fractions into arrays, coalescing missing bins to 0
        coalesce = Arel::Nodes::NamedFunction.new('COALESCE', [score_bin_fractions[:bin_fraction], 0])

        bin_series.project(
          bin_series[:tag_id],
          bin_series[:provenance_id],
          coalesce.array_agg.as('bin_fraction')
        ).join(score_bin_fractions, Arel::Nodes::OuterJoin)
          .on(
          Arel::Nodes::And.new([
            bin_series[:tag_id].eq(score_bin_fractions[:tag_id]),
            bin_series[:provenance_id].eq(score_bin_fractions[:provenance_id]),
            bin_series[:bin_id].eq(score_bin_fractions[:bin_id])
          ])
        ).group(bin_series[:tag_id], bin_series[:provenance_id])
      }

      # Aggregate all results into event_summaries JSON for reporting
      # Each row is a tag/provenance summary with event and score histogram data
      step table: TABLE_EVENT_SUMMARIES, depends_on: [TABLE_VERIFICATION_COUNTS_PER_TAG_PROVENANCE, TABLE_BIN_SERIES_SCORES], as: proc { |_t, verification_counts, bin_series_scores|
        # NOTE: the event_summaries are tag + audio_event (tagging) centric;
        # each summary datum for a tag has a count of events. since it's
        # possible to have more one tagging for an event, an event associated
        # with more than one tag will be counted more than once (across the
        # series). I.e., the 'count' fields, when summed across all
        # event_summaries, will equal the length of taggings.
        events_json = event_summary_counts_and_consensus_as_json(verification_counts)
        scores_json = score_histogram_as_json(verification_counts, bin_series_scores)

        verification_counts.project(
          verification_counts[:provenance_id],
          verification_counts[:tag_id],
          events_json.as('events'),
          scores_json.as('score_histogram')
        ).group(
          verification_counts[:tag_id],
          verification_counts[:provenance_id]
        ).join(bin_series_scores, Arel::Nodes::OuterJoin)
          .on(verification_counts[:tag_id].eq(bin_series_scores[:tag_id])
          .and(verification_counts[:provenance_id].eq(bin_series_scores[:provenance_id])))
      }

      # Project method for the final JSON aggregation Returns an
      # Arel::SelectManager that projects the aggregated event summaries as JSON
      def project(_collection = nil, _options = nil)
        event_summaries_aliased = TABLE_EVENT_SUMMARIES.as('e')
        Arel::SelectManager.new
          .project(event_summaries_aliased.right.json_agg)
          .from(event_summaries_aliased)
      end

      def null_if(column, value)
        Arel::Nodes::NamedFunction.new 'NULLIF', [column, value]
      end

      def event_summary_counts_and_consensus_as_json(source)
        json = Arel.json({
          count: source[:count],
          verifications: source[:verifications],
          consensus: source[:consensus]
        }).group # => jsonb_agg(jsonb_build_object (...))
      end

      def score_histogram_as_json(source, score_bins_table)
        json = Arel.json({
          bins: score_bins_table[:bin_fraction],
          standard_deviation: source[:score_stdev].round(3),
          mean: source[:score_mean].round(3),
          min: source[:score_min],
          max: source[:score_max]
        }).group # => jsonb_agg(jsonb_build_object (...))
      end

      def verifications = Verification.arel_table
    end
  end
end
