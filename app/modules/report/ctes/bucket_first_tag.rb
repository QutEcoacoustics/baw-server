# frozen_string_literal: true

module Report
  module Ctes
    # To get an accumulated count of unique tags, we first need to know where
    # the tag is first seem (at which bucket).
    class BucketFirstTag < Report::Cte::NodeTemplate

      table_name :bucket_first_tag

      depdendencies bucket_allocate: Report::Ctes::BucketAllocate

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
