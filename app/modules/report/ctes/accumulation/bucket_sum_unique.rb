# frozen_string_literal: true

module Report
  module Ctes
    module Accumulation
      # For each bucket, sum the number of tags that were seen for the first time
      #
      # == query output
      #  emits columns:
      #    sum_new_tags (int)  -- number of new tags seen in this bucket
      #    bucket (int)        -- the bucket number
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
