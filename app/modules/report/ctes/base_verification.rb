# frozen_string_literal: true

module Report
  module Ctes
    # Base class for event reports that use time series data.

    # @see Report::Ctes::BucketAllocate
    # @see Report::Ctes::BucketFirstTag
    # @see Report::Ctes::BucketTsRange
    # @see Report::Ctes::TsRangeAndInterval
    class BaseVerification < Report::Cte::NodeTemplate

      table_name :base_verification

      dependencies base_table: Report::Ctes::BaseEventReport

      select do
        Arel::SelectManager.new.project(
          base_table[:audio_event_id],
          base_table[:tag_id],
          base_table[:provenance_id],
          base_table[:score],
          verifications[:id].as('verification_id'),
          verifications[:confirmed]
        )
          .from(base_table)
          .join(verifications, Arel::Nodes::OuterJoin)
          .on(base_table[:audio_event_id].eq(verifications[:audio_event_id])
          .and(base_table[:tag_id].eq(verifications[:tag_id])))
      end

      def self.verifications
        @verifications ||= Verification.arel_table
      end
    end
  end
end
