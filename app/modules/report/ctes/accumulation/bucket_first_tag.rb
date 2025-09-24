# frozen_string_literal: true

module Report
  module Ctes
    module Accumulation
      # To get an accumulated count of unique tags, we first need to know where
      # each tag is first seem (at which bucket).
      #
      # == query output
      #
      #  emits columns:
      #    bucket (int)       -- the bucket number
      #    tag_id (int)
      #    score  (int)
      #    is_first_time (int) -- 1 the first time a tag is seen in a bucket, else 0
      class BucketFirstTag < Cte::NodeTemplate
        table_name :bucket_first_tag

        dependencies bucket_allocate: BucketAllocate

        select do
          window = Arel::Nodes::Window.new.partition(bucket_allocate[:tag_id]).order(bucket_allocate[:bucket])
          tag_first_appearance = Arel::Nodes::Case.new.when(
            Arel::Nodes::NamedFunction.new('row_number', []).over(window).eq(1)
          ).then(1).else(0)

          bucket_allocate.project(
            bucket_allocate[:bucket], bucket_allocate[:tag_id], bucket_allocate[:score],
            tag_first_appearance.as('is_first_time')
          ).where(bucket_allocate[:bucket].eq(nil).invert)
        end
      end
    end
  end
end
