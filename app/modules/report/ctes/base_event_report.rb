# frozen_string_literal: true

module Report
  module Ctes
    # Base class for event reports that use time series data.

    # @see Report::Ctes::BucketAllocate
    # @see Report::Ctes::BucketFirstTag
    # @see Report::Ctes::BucketTsRange
    # @see Report::Ctes::TsRangeAndInterval
    class BaseEventReport < Report::Cte::Node
      include Cte::Dsl

      table_name :base_table

      select do
        AudioEvent.joins(:audio_recording, :taggings)
          .select(accumulation_columns).select_start_absolute.arel
      end

      def self.accumulation_columns
        [:id, :tag_id, :score]
      end
    end
  end
end
