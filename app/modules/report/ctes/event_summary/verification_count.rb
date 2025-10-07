# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      #
      # Counts verifications per tag, provenance, audio event, and confirmation status.
      #
      # This CTE calculates the count of verifications for each category (e.g.,
      # 'correct', 'incorrect') and the ratio of each category's count to the
      # total count for the group.
      #
      # == query output
      #
      #  emits columns:
      #    tag_id (int) -- the id of the tag
      #    provenance_id (int) -- the id of the provenance
      #    audio_event_id (int) -- the id of the audio event
      #    score (numeric) -- the score of the audio event
      #    confirmed (boolean) -- the confirmation status of the verification
      #    category_count (int) -- the number of verifications in the category
      #    ratio (float) -- the ratio of category_count to the total verifications for the event
      #
      class VerificationCount < Cte::NodeTemplate
        table_name :verification_count
        dependencies base_verification: Report::Ctes::BaseVerification
        select do
          window = Arel::Nodes::Window.new.partition(
            base_verification[:tag_id],
            base_verification[:provenance_id],
            base_verification[:audio_event_id]
          )
          count_sum_over = base_verification[:verification_id].count.sum.over(window).coalesce(0)
          count_sum_over_nullif = Arel::Nodes::NamedFunction.new('NULLIF', [count_sum_over, Arel.quoted(0)])

          base_verification.project(
            base_verification[:tag_id],
            base_verification[:provenance_id],
            base_verification[:audio_event_id],
            base_verification[:score],
            base_verification[:confirmed],
            base_verification[:verification_id].count.as('category_count'),
            base_verification[:verification_id].count.coalesce(0).cast('float') / count_sum_over_nullif.as('ratio')
          ).group(
            base_verification[:tag_id],
            base_verification[:provenance_id],
            base_verification[:audio_event_id],
            base_verification[:confirmed],
            base_verification[:score]
          )
        end
      end
    end
  end
end
