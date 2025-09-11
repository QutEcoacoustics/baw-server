# frozen_string_literal: true

module Report
  module Ctes
    # Use the width_bucket function to return a query that categorises input
    # data by bucket number
    #
    # atm tightly coupled to a base table that has start_time_absolute, tag_id
    # and score columns. decouple in the future; just requires a timestamp field on
    # the base table as input, and desired output projection fields
    class BucketAllocate < Report::Cte::NodeTemplate
      extend Report::TimeSeries

      table_name :bucket_allocate

      dependencies bucket_count: Report::Ctes::BucketCount, base_table: Report::Ctes::BaseEventReport

      select do
        width_bucket_expr = Arel::Nodes::NamedFunction.new('width_bucket', [
          base_table[:start_time_absolute].extract('epoch'),
          bucket_count.project(bucket_count[:time_range].lower.extract('epoch')),
          bucket_count.project(upper(bucket_count[:time_range]).extract('epoch')),
          bucket_count.project(bucket_count[:bucket_count].ceil.cast('int'))
        ])
        base_table.project(
          width_bucket_expr.as('bucket'),
          base_table[:tag_id],
          base_table[:score]
        )
      end
    end
  end
end
