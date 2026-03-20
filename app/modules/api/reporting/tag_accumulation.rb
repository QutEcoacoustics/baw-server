# frozen_string_literal: true

module Api
  module Reporting
    # Report template with the required CTEs and joins to produce a report of
    # cumulative unique tag counts over time buckets.
    #
    # Implements #call(query) for use as a template in execute_report.
    class TagAccumulation
      include CteHelper

      EVENTS     = Arel::Table.new(:filtered_events)
      FIRST_SEEN = Arel::Table.new(:first_seen_per_tag)
      NEW_TAGS   = Arel::Table.new(:new_tags)

      # @param options [Hash]
      # @option options [String] :bucket_size required
      def initialize(options = {})
        @bucketer = Bucketer.new(options)
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        query = query.joins(joins)

        # Each tag_first_seen_bucket belongs to one [unit, unit+1) tsrange
        Arel::SelectManager.new
          .with(*ctes(query:))
          .from(Bucketer::BUCKETS)
          .join(NEW_TAGS, Arel::Nodes::OuterJoin)
          .on(Bucketer::BUCKETS[:bucket].contains(NEW_TAGS[:tag_first_seen_bucket]))
          .order(Bucketer::BUCKETS[:bucket])
      end

      # Arel expression to project cumulative unique tag count up to and
      # including each bucket.
      # @return [Arel::Nodes::Over]
      def self.cumulative_count
        # Cumulative count will stay flat on buckets with no newly seen tags
        new_count = Arel.coalesce(NEW_TAGS[:new_tag_count], 0).sum
        window = Arel::Nodes::Window.new
          .order(Bucketer::BUCKETS[:bucket])
          .tap { |w| w.rows(Arel::Nodes::Preceding.new) }

        new_count.over(window)
      end

      private

      def joins = { taggings: [:tag] }

      def ctes(query:)
        bucket_size = @bucketer.options.bucket_size

        # Events_cte contains the effective_permissions cte;
        # it becomes a nested cte in the final query (no performance impact).
        [
          cte(EVENTS, events_cte(query)),
          *@bucketer.bucket_ctes(events_table: EVENTS),
          cte(FIRST_SEEN, first_seen_cte(bucket_size)),
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

      # To get the cumulative unique tag count, we only depend on when a tag *first* appears,
      # so we collapse each tag to exactly one row - the first bucket it appears in
      def first_seen_cte(interval)
        EVENTS
          .project(EVENTS[:tag_id], Arel.date_trunc(interval, EVENTS[:start_at]).minimum.as('tag_first_seen_bucket'))
          .group(EVENTS[:tag_id])
      end

      # Now we can just count how many tags are first seen in each bucket -
      # this is what will be accumulated in the final step
      def new_tags_cte
        FIRST_SEEN
          .project(FIRST_SEEN[:tag_first_seen_bucket], Arel.star.count.as('new_tag_count'))
          .group(FIRST_SEEN[:tag_first_seen_bucket])
      end
    end
  end
end
