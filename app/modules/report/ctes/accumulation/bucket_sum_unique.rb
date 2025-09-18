# frozen_string_literal: true

module Report
  module Ctes
    module Accumulation
      class BucketSumUnique < Cte::NodeTemplate
        table_name :bucket_sum_unique

        dependencies first_tag: BucketFirstTag

        select do
          first_tag.project(
            first_tag[:is_first_time].sum.as('sum_new_tags'),
            first_tag[:bucket]
          ).group(first_tag[:bucket])
        end
      end
    end
  end
end
