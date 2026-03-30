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
      DISTINCT_TAGS = Arel::Table.new(:distinct_tags)

      # @param options [Hash]
      # @option options [String] :bucket_size required
      def initialize(options = {})
        @bucketer = Bucketer.new(options)
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        query = query.joins(joins)

        # count events per bucket per tag:
        Arel::SelectManager.new
          .project(
            Bucketer::BUCKETS[:bucket].as('bucket'),
            DISTINCT_TAGS[:tag_id]
          )
          .with(*ctes(query:))
          .from(Bucketer::BUCKETS)
          .join(DISTINCT_TAGS).on(Arel.sql('true'))
          .join(EVENTS, Arel::Nodes::OuterJoin)
          .on(EVENTS[:tag_id].eq(DISTINCT_TAGS[:tag_id])
            .and(Bucketer::BUCKETS[:bucket].contains(EVENTS[:start_at])))
          .group(Bucketer::BUCKETS[:bucket], DISTINCT_TAGS[:tag_id])
          .order(Bucketer::BUCKETS[:bucket], DISTINCT_TAGS[:tag_id])
      end

      # project total count of events with tags per bucket. Used to calculate % of events with each tag.
      def self.window_bucket_count
        window = Arel::Nodes::Window.new.partition(Bucketer::BUCKETS[:bucket])
        window_bucket_count = EVENTS[:tag_id].count.sum.over(window)
      end

      # Arel expression to project tag frequency
      def self.tag_frequency
        EVENTS[:tag_id].count
      end

      private

      def joins = { taggings: [:tag] }

      def ctes(query:)
        [
          cte(EVENTS, events_cte(query)),
          *@bucketer.bucket_ctes(events_table: EVENTS),
          cte(DISTINCT_TAGS, distinct_tags_cte)
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

      def distinct_tags_cte
        EVENTS.project(EVENTS[:tag_id].distinct)
      end
    end
  end
end
