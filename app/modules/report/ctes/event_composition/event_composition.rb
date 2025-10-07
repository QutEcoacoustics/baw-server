# frozen_string_literal: true

module Report
  module Ctes
    #
    # The EventComposition module provides a namespace for CTE templates used
    # for calculating an event composition time series. Event composition is the
    # ratio of different tags within time buckets over a specified interval.
    #
    module EventComposition
      #
      # Root CTE template for an event composition time series result.
      #
      # Formats the results of {CompositionSeries} into a JSON array, used in
      # the {AudioEventSummary} report.
      #
      # == query output
      #
      #  emits column:
      #    composition_series (json) -- an array of bucket objects. Length = num buckets * num unique tags
      #
      #  emits json fields in composition_series[*]:
      #    bucket_number (numeric)
      #    tag_id (int)        -- the id of the tag
      #    range (string)      -- tsrange literal in canonical form, `[inclusive start, exclusive end)`
      #    count (int)         -- the count of events with this tag in the bucket
      #    verifications (int) -- the total number of verifications for events with this tag in the bucket
      #    consensus (numeric) -- the average consensus ratio for events with this tag in the bucket
      #    total_tags_in_bin (int) -- the total count of events for all tags in the bucket
      #
      # @example Basic usage
      #   result = Report::Ctes::EventComposition::EventComposition.execute
      #   series = Report::Ctes::EventComposition::EventComposition.format_result(result.first)
      class EventComposition < Cte::NodeTemplate
        table_name :event_composition

        dependencies composition_series: CompositionSeries

        select do
          composition_series_aliased = composition_series.as('c')
          Arel::SelectManager.new
            .project(composition_series_aliased.right.json_agg.as('composition_series'))
            .from(composition_series_aliased)
        end

        # Format an EventComposition result hash.
        #
        # For each input row of the result set, add a `ratio` key, calculated as
        #  the ratio of tag count to total tags in the bin. Restructure the row
        #  hash, nesting `count`, `verifications`, and `consensus` under an
        #  `events` key.
        #
        def self.format_result(result, base_key = 'composition_series', suffix: nil)
          key = suffix ? "#{base_key}_#{suffix}" : base_key

          # The keys we expect in the result rows
          result_keys = {
            count: 'count',
            total: 'total_tags_in_bin',
            ratio: 'ratio'
          }

          calculate_ratio = lambda { |count, total|
            total.zero? ? 0 : (count.to_f / total).round(2)
          }

          add_ratio_field = lambda { |row|
            count = row.fetch(result_keys[:count], 0)
            total = row.fetch(result_keys[:total], 0)
            ratio = calculate_ratio.call(count, total)

            row.merge(result_keys[:ratio] => ratio)
          }

          # Structure the output to match our expected format
          output_structure = {
            top_level_fields: ['range', 'tag_id', 'ratio'],
            nested_fields: ['count', 'verifications', 'consensus']
          }

          restructure_hash = lambda { |row|
            base_hash = row.slice(*output_structure[:top_level_fields])
            events_hash = row.slice(*output_structure[:nested_fields])
            base_hash.merge('events' => events_hash)
          }

          Decode.transform_tsrange >> add_ratio_field >> restructure_hash => transform

          Decode.json result[key], &transform
        end
      end
    end
  end
end
