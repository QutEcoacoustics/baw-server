# frozen_string_literal: true

module Report
  module Ctes
    # Use the width_bucket function to categorise audio_events into buckets.
    # Project tag id and score, for calculating unique tags later.
    #
    # == query output
    #
    #  emits columns:
    #    bucket (int)  --  the bucket number for an input value
    #    tag_id (int)
    #    score  (int)
    #
    # @note for the audio event report, the default value for
    #   base_table.start_time_abolsute is audio_event start time.
    #   but you could use a custom base_table with any timestamp data in this
    #   field. then subclass this template to override base_table, or use the
    #   Cte::Node registry to inject it.
    module Accumulation
      class BucketAllocate < Cte::NodeTemplate
        extend Report::TimeSeries

        table_name :bucket_allocate

        # BucketCount provides the arguments used in width_bucket
        dependencies bucket_count: BucketCount, base_table: BaseEventReport

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
end
