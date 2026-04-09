# frozen_string_literal: true

module Api
  module Reporting
    # Report template with the required CTEs and joins to produce a report of
    # diel activity, i.e. tag frequencies over configurable time buckets aligned
    # to a 24-hour period.
    #
    # Implements #call(query) for use as a template in execute_report.
    class TagDielActivity
      include CteHelper

      EVENTS = Arel::Table.new(:filtered_events)
      COUNT_EVENTS = Arel::Table.new(:count_events)
      COUNT_EVENTS_BUCKETED = Arel::Table.new(:count_events_bucketed)

      BUCKET_LOWER = :bucket_lower
      EVENT_BUCKET_LOWER = :event_bucket_lower
      SECONDS_IN_A_DAY = 86_400
      INTERVALS = {
        'minute' => 60,
        'halfhour' => 1800,
        'hour' => 3600
      }.freeze

      # Duration in :seconds and number of buckets to cover a 24-hour period
      Config = Data.define(:bucket_size)

      # @param options [Hash]
      # @option options [String] :bucket_size required
      def initialize(options = {})
        size = options.fetch(:bucket_size)
        config = INTERVALS.fetch(size) { invalid_bucket_size!(size) }

        @config = Config.new(config)
      end

      # @param query [ActiveRecord::Relation] base query
      # @return [Arel::SelectManager]
      def call(query)
        query = query.joins(joins)

        COUNT_EVENTS_BUCKETED
          .project(bucket_array)
          .with(*ctes(query:))
          .group(COUNT_EVENTS_BUCKETED[BUCKET_LOWER])
          .order(COUNT_EVENTS_BUCKETED[BUCKET_LOWER])
      end

      # Arel expression for a JSON array of tag_id and event count pairs,
      # coalescing to an empty array for null tags.
      def self.tag_frequency_array
        Arel
          .json({
            tag_id: COUNT_EVENTS_BUCKETED[:tag_id],
            events: COUNT_EVENTS_BUCKETED[:events]
          })
          .group
          .filter(COUNT_EVENTS_BUCKETED[:tag_id].is_not_null)
          .coalesce('[]')
      end

      private

      def joins = { taggings: [:tag] }

      def ctes(query:)
        [
          cte(EVENTS, events_cte(query)),
          cte(COUNT_EVENTS, count_events_cte),
          cte(COUNT_EVENTS_BUCKETED, count_events_bucketed_cte)
        ]
      end

      def events_cte(query)
        bucket_index = (audio_event_seconds_from_midnight / @config.bucket_size).floor
        event_bucket_lower = bucket_index * @config.bucket_size

        query
          .except(:select, :order, :limit, :offset)
          .reselect(
            Tagging.arel_table[:tag_id].as('tag_id'),
            event_bucket_lower.as(EVENT_BUCKET_LOWER.to_s)
          ).arel
      end

      def count_events_cte
        EVENTS
          .project(Arel.star, EVENTS[:tag_id].count.as('events'))
          .group(EVENTS[EVENT_BUCKET_LOWER], EVENTS[:tag_id])
      end

      def count_events_bucketed_cte
        final_bucket_lower = SECONDS_IN_A_DAY - @config.bucket_size

        buckets = Arel::Table.new('buckets')
        bucket_series = Arel.generate_series(0, final_bucket_lower, @config.bucket_size).as(BUCKET_LOWER.to_s)
        bucket_series_query = Arel::SelectManager.new.project(bucket_series).as(buckets.name)

        Arel::SelectManager.new
          .project(
            COUNT_EVENTS[:tag_id],
            COUNT_EVENTS[:events],
            buckets[BUCKET_LOWER]
          )
          .from(bucket_series_query)
          .join(COUNT_EVENTS, Arel::Nodes::OuterJoin)
          .on(COUNT_EVENTS[EVENT_BUCKET_LOWER].eq(buckets[BUCKET_LOWER]))
      end

      # Used to align event start times to a common diel period
      def midnight(col) = Arel.date_trunc('day', col) # + offset

      # Subtracting midnight gives seconds since the start of the diel period, which can then be bucketed
      def audio_event_seconds_from_midnight
        # ! TODO: remove Subtraction.new when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel::Nodes::Subtraction.new(
          AudioEvent.start_date_arel,
          midnight(AudioEvent.start_date_arel)
        ).extract('epoch')
      end

      def bucket_array
        # ! TODO: remove Addition.new when arel-extensions is removed. See https://github.com/QutEcoacoustics/baw-server/issues/966
        Arel.json([
          COUNT_EVENTS_BUCKETED[BUCKET_LOWER],
          Arel::Nodes::Addition.new(COUNT_EVENTS_BUCKETED[BUCKET_LOWER], @config.bucket_size)
        ]).as('bucket')
      end

      def invalid_bucket_size!(size) = raise KeyError, "#{size} not in #{INTERVALS.keys}"
    end
  end
end
