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
    end
  end
end
