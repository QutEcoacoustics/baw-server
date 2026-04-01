# frozen_string_literal: true

module Api
  module Reporting
    # Report template with the required CTEs and joins to produce a report of
    # tag frequencies over time buckets.
    #
    # Implements #call(query) for use as a template in execute_report.
    class TagFrequency
      include CteHelper

      EVENTS = Arel::Table.new(:filtered_events)
      TAGS_PER_BUCKET = Arel::Table.new(:event_buckets)
      BUCKETS_JOINED = Arel::Table.new(:count_tags)

      # @param options [Hash]
      # @option options [String] :bucket_size required
      def initialize(options = {})
        @bucketer = Bucketer.new(options)
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        query = query.joins(joins)

        BUCKETS_JOINED
          .project(BUCKETS_JOINED[:bucket])
          .with(*ctes(query:))
          .group(BUCKETS_JOINED[:bucket])
          .order(BUCKETS_JOINED[:bucket])
      end

      # Arel expression for a JSON array of tag_id and event count pairs,
      # coalescing to an empty array for null tags.
      def self.tag_frequency_array
        Arel.json({
          tag_id: BUCKETS_JOINED[:tag_id],
          events: BUCKETS_JOINED[:events]
        })
          .group
          .filter(BUCKETS_JOINED[:tag_id].is_not_null)
          .coalesce('[]')
      end

      private

      def joins = { taggings: [:tag] }

      def ctes(query:)
        [
          cte(EVENTS, events_cte(query)),
          *@bucketer.bucket_ctes(events_table: EVENTS),
          cte(TAGS_PER_BUCKET, tags_per_bucket_cte),
          cte(BUCKETS_JOINED, buckets_joined)
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

      # To get tag frequency per bucket, we first aggregate events by bucket and tag_id,
      # which allows a join to the final bucket series based on bucket
      # equality in the next CTE, `buckets_joined`.
      #
      # Adding the bucket to the events allows us to group events efficiently.
      # We use date_trunc to widen an event date into a bucket.
      #
      # This pre-grouping is important because it allows us to join on B:B buckets
      # instead of B:N (buckets to tag count), which is a massive performance win.
      def tags_per_bucket_cte
        bucket = @bucketer.bucket(column: EVENTS[:start_at])

        EVENTS.project(
          EVENTS[:tag_id],
          Arel.star.count.as('events'),
          bucket.dup.as('event_bucket')
        ).group(bucket, EVENTS[:tag_id])
      end

      def buckets_joined
        Bucketer::BUCKETS
          .project(
            Bucketer::BUCKETS[:bucket],
            TAGS_PER_BUCKET[:tag_id],
            TAGS_PER_BUCKET[:events]
          )
          .join(TAGS_PER_BUCKET, Arel::Nodes::OuterJoin)
          .on(TAGS_PER_BUCKET[:event_bucket].eq(Bucketer::BUCKETS[:bucket]))
      end
    end
  end
end
