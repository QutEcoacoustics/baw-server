# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      # Generates a histogram of scores for audio events, grouped by tag and provenance.
      #
      # Score histogram binning steps
      # score_bins: Bin scores into 50 buckets for each tag/provenance
      # score_bin_fractions: Calculate fraction of scores in each bin
      # bin_series: Generate complete series of bins for each tag/provenance (CROSS JOIN)
      # bin_series_scores: Aggregate bin fractions into arrays
      # scores are binned into 50 buckets for unique tag/provenance
      class ScoreHistogram < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :score_histogram
        depends_on base_table: Report::Ctes::BaseEventReport

        SCORE_BINS = 50

        select do
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
        end
      end

      # calculate the fraction of scores in each bin, relative to the total for that tag/provenance group
      class ScoreBinFractions < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :score_bin_fractions
        depends_on score_bins: Report::Ctes::EventSummary::ScoreHistogram
        select do
          null_if_count = null_if(score_bins[:group_count], 0)
          score_bins.project(
            score_bins[:tag_id],
            score_bins[:provenance_id],
            score_bins[:bin_id],
            score_bins[:bin_count],
            score_bins[:group_count],
            (score_bins[:bin_count].cast('numeric') / null_if_count).round(3).as('bin_fraction')
          )
        end

        def self.null_if(column, value)
          Arel::Nodes::NamedFunction.new 'NULLIF', [column, value]
        end
      end

      # get the complete series of bins 1 to 50 for unique tag_id and provenance_id
      class BinSeries < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :bin_series
        depends_on base_table: Report::Ctes::BaseEventReport
        select do
          generate_series = Report::TimeSeries.generate_series(50).as('bin_id')
          cross_join = Arel::Nodes::StringJoin.new(Arel.sql('CROSS JOIN ?', generate_series))

          distinct_tag_provenance = base_table.dup
            .project(base_table[:tag_id], base_table[:provenance_id])
            .distinct
            .as('distinct_tag_provenance')

          # include distinct_tag_provenance as a subquery
          select = Arel::SelectManager.new.project(
            distinct_tag_provenance[:tag_id],
            distinct_tag_provenance[:provenance_id],
            generate_series.right
          ).from(distinct_tag_provenance)

          select.join_sources << cross_join
          select
        end
      end

      class BinSeriesScores < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :bin_series_scores
        depends_on bin_series: Report::Ctes::EventSummary::BinSeries,
          score_bin_fractions: Report::Ctes::EventSummary::ScoreBinFractions

        select do
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
        end
      end

      # Aggregate all results into event_summaries JSON for reporting
      # Each row is a tag/provenance summary with event and score histogram data
      class EventSummary < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :event_summary
        depends_on event_summary_statistics: Report::Ctes::EventSummary::EventSummaryStatistics,
          bin_series_scores: Report::Ctes::EventSummary::BinSeriesScores
        select do
          # NOTE: the event_summaries are tag + audio_event (tagging) centric;
          # each summary datum for a tag has a count of events. since it's
          # possible to have more one tagging for an event, an event associated
          # with more than one tag will be counted more than once (across the
          # series). I.e., the 'count' fields, when summed across all
          # event_summaries, will equal the length of taggings.
          events_json = event_summary_counts_and_consensus_as_json(event_summary_statistics)
          scores_json = score_histogram_as_json(event_summary_statistics, bin_series_scores)

          event_summary_statistics.project(
            event_summary_statistics[:provenance_id],
            event_summary_statistics[:tag_id],
            events_json.as('events'),
            scores_json.as('score_histogram')
          ).group(
            event_summary_statistics[:tag_id],
            event_summary_statistics[:provenance_id]
          ).join(bin_series_scores, Arel::Nodes::OuterJoin)
            .on(event_summary_statistics[:tag_id].eq(bin_series_scores[:tag_id])
            .and(event_summary_statistics[:provenance_id].eq(bin_series_scores[:provenance_id])))
        end

        def self.event_summary_counts_and_consensus_as_json(source)
          Arel.json({
            count: source[:count],
            verifications: source[:verifications],
            consensus: source[:consensus]
          }).group # => jsonb_agg(jsonb_build_object (...))
        end

        def self.score_histogram_as_json(source, score_bins_table)
          Arel.json({
            bins: score_bins_table[:bin_fraction],
            standard_deviation: source[:score_stdev].round(3),
            mean: source[:score_mean].round(3),
            min: source[:score_min],
            max: source[:score_max]
          }).group # => jsonb_agg(jsonb_build_object (...))
        end
      end

      class EventSummaryAggregate < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :event_summary_aggregate
        depends_on event_summary: Report::Ctes::EventSummary::EventSummary
        select do
          event_summaries_aliased = event_summary.as('e')
          Arel::SelectManager.new
            .project(event_summaries_aliased.right.json_agg)
            .from(event_summaries_aliased)
        end
      end
    end
  end
end
