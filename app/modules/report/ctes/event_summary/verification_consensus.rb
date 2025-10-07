# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      #
      # Calculates the consensus for each audio event.
      #
      # The consensus is defined as the maximum ratio of verifications for any
      # single confirmation status for a given audio event. For example, an event with
      # 3 'correct' and 1 'incorrect' verifications has a consensus of 0.75.
      # For an event with 1 'unsure', 1 'incorrect', 1 'skipped' and 2 'correct', the highest
      # ratio is for 'correct' with 2 out of 5 verifications.
      #
      # This CTE also calculates the total number of verifications for the event.
      #
      # == query output
      #
      #  emits columns:
      #    tag_id (int) -- the id of the tag
      #    provenance_id (int) -- the id of the provenance
      #    audio_event_id (int) -- the id of the audio event
      #    score (numeric) -- the score of the audio event
      #    consensus_for_event (numeric) -- the consensus value for the event
      #    total_verifications_for_event (int) -- total verifications for the event
      #
      class VerificationConsensus < Cte::NodeTemplate
        table_name :verification_consensus
        dependencies verification_count: Report::Ctes::EventSummary::VerificationCount
        select do
          verification_count.project(
            verification_count[:tag_id],
            verification_count[:provenance_id],
            verification_count[:audio_event_id],
            verification_count[:score],
            verification_count[:ratio].maximum.as('consensus_for_event'),
            verification_count[:category_count].sum.as('total_verifications_for_event')
          ).group(
            verification_count[:tag_id],
            verification_count[:provenance_id],
            verification_count[:audio_event_id],
            verification_count[:score]
          )
        end
      end
    end
  end
end
