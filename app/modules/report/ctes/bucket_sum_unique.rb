# frozen_string_literal: true

module Report
  module Ctes
    class BucketSumUnique < Report::Cte::Node
      include Cte::Dsl

      table_name :bucket_sum_unique

      depends_on first_tag: Report::Ctes::BucketFirstTag

      select do
        first_tag.project(
          first_tag[:is_first_time].sum.as('sum_new_tags'),
          first_tag[:bucket]
        ).group(first_tag[:bucket])
      end
    end
  end
end
