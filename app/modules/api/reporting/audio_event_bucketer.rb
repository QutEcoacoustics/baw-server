# frozen_string_literal: true

module Api
  module Reporting
    class AudioEventBucketer
      EVENTS     = Arel::Table.new(:filtered_events)
      BOUNDS     = Arel::Table.new(:bounds)
      BUCKETS    = Arel::Table.new(:audio_event_buckets)
      FIRST_SEEN = Arel::Table.new(:first_seen_per_tag)
      NEW_TAGS   = Arel::Table.new(:new_tags)

      INTERVALS = {
        'day' => { days: 1 },
        'week' => { weeks: 1 },
        'month' => { months: 1 },
        'year' => { years: 1 }
      }.freeze

      class << self
        def call(query, options)
          interval = options[:bucket_size]
          interval_arel = make_interval(options[:bucket_size])

          # each tag_first_seen_bucket belongs to exactly one [unit, unit+1) tsrange
          Arel::SelectManager.new
            .with(*ctes(query:, interval:, interval_arel:))
            .from(BUCKETS)
            .project(BUCKETS[:bucket], cumulative_count)
            .join(NEW_TAGS, Arel::Nodes::OuterJoin)
            .on(BUCKETS[:bucket].contains(NEW_TAGS[:tag_first_seen_bucket]))
            .order(BUCKETS[:bucket_lower])
        end

        private

        def ctes(query:, interval:, interval_arel:)
          # events_cte contains the effective_permissions cte;
          # it becomes a nested cte in the final query (no performance impact).
          [
            cte(EVENTS, events_cte(query)),
            cte(BOUNDS, bounds_cte(interval)),
            cte(BUCKETS, buckets_cte(interval_arel)),
            cte(FIRST_SEEN, first_seen_cte(interval)),
            cte(NEW_TAGS, new_tags_cte)
          ]
        end

        def events_cte(query)
          query
            .except(:select, :order, :limit, :offset)
            .reselect(
              Tagging.arel_table[:tag_id].as('tag_id'),
              AudioEvent.start_date_arel.as('start_at'),
              AudioEvent.end_date_arel.as('end_at')
            ).arel
        end

        # use the audio events to determine bounds for generating the bucket series
        def bounds_cte(interval)
          EVENTS.project(
            date_trunc(interval, EVENTS[:start_at].minimum).as('series_start'),
            date_trunc(interval, EVENTS[:end_at].maximum).as('series_end')
          )
        end

        # using the bounds and supplied interval to generate the main bucket cte
        def buckets_cte(interval_arel)
          series = generate_series(BOUNDS[:series_start], BOUNDS[:series_end], interval_arel).as('bucket_lower')
          lower = series.right
          upper = Arel::Nodes::InfixOperation.new('+', lower, interval_arel)

          result = BOUNDS.project(lower, tsrange(lower, upper).as('bucket'))
          result.join_sources << Arel::Nodes::StringJoin.new(Arel.sql('CROSS JOIN LATERAL ?', series))
          result
        end

        # to get the cumulative unique tag count, we only depend on when a tag *first* appears
        # so we collapse each tag to exactly one row - the first bucket it appears in
        def first_seen_cte(interval)
          EVENTS
            .project(EVENTS[:tag_id], date_trunc(interval, EVENTS[:start_at]).minimum.as('tag_first_seen_bucket'))
            .group(EVENTS[:tag_id])
        end

        # now we can just count how many tags are first seen in each bucket
        # this is what will be accumulated in the final step
        def new_tags_cte
          FIRST_SEEN
            .project(FIRST_SEEN[:tag_first_seen_bucket], Arel.star.count.as('new_tag_count'))
            .group(FIRST_SEEN[:tag_first_seen_bucket])
        end

        def cumulative_count
          # COALESCE(0) so cumulative count will stay flat on days with no newly seen tags
          new_count = Arel.coalesce(NEW_TAGS[:new_tag_count], 0).sum
          window = Arel::Nodes::Window.new
            .order(BUCKETS[:bucket_lower])
            .tap { |w| w.rows(Arel::Nodes::Preceding.new) }

          new_count.over(window).as('cumulative_unique_tag_count')
        end

        def make_interval(bucket_size)
          args = INTERVALS.fetch(bucket_size) {
            raise ArgumentError, "invalid bucket_size #{bucket_size}: expected day, week, month, or year"
          }
          Baw::Arel::Nodes::MakeInterval.new(**args)
        end

        def cte(table, query) = Arel::Nodes::As.new(table, query)

        # TODO: Move the arel helpers

        def generate_series(start, stop, step)
          Arel::Nodes::NamedFunction.new('generate_series', [start, stop, step])
        end

        def date_trunc(interval, node)
          Arel::Nodes::NamedFunction.new('date_trunc', [Arel.quoted(interval), node])
        end

        def tsrange(lower, upper, bounds = '[)')
          Arel::Nodes::NamedFunction.new('tsrange', [lower, upper, Arel.quoted(bounds)])
        end
      end
    end
  end
end
