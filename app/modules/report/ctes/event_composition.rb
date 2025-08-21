# frozen_string_literal: true

module Report
  module Ctes
    # Time series aggregation across dimensions (time, tag_id) that
    # counts distinct audio events and verifications per group. Expect nrows
    # to be equal to the number of tags * number of buckets.
    class EventComposition < Report::Cte::Node
      include Cte::Dsl

      table_name :event_composition

      depends_on composition_series: Report::Ctes::CompositionSeries

      select do
        composition_series_aliased = composition_series.as('c')
        Arel::SelectManager.new
          .project(composition_series_aliased.right.json_agg.as('composition_series'))
          .from(composition_series_aliased)
      end

      def self.format_result(result, base_key = 'composition_series', suffix: nil)
        key = suffix ? "#{base_key}_#{suffix}" : base_key
        opts = {
          count_key: 'count',
          total_key: 'total_tags_in_bin',
          ratio_key: 'ratio',
          fields: ['range', 'tag_id', 'ratio'],
          events_hash_fields: ['count', 'verifications', 'consensus']
        }

        calculate_ratio = lambda { |count, total|
          total.zero? ? 0 : (count.to_f / total).round(2)
        }

        add_ratio_field = lambda { |row|
          count = row.fetch(opts[:count_key], 0)
          total = row.fetch(opts[:total_key], 0)
          ratio = calculate_ratio.call(count, total)

          row.merge(opts[:ratio_key] => ratio)
        }

        # structure the output to match our expected format
        restructure_hash = lambda { |row|
          base_hash = row.slice(*opts[:fields])
          events_hash = row.slice(*opts[:events_hash_fields])
          base_hash.merge('events' => events_hash)
        }

        Decode.transform_tsrange >> add_ratio_field >> restructure_hash => transform

        Decode.json result[key], &transform
      end
    end
  end
end
