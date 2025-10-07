# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      #
      # Calculates summary statistics for audio events per tag and provenance.
      #
      # This CTE aggregates data from {VerificationConsensus} to compute
      # statistics like count, mean score, standard deviation, and total
      # verifications for each tag/provenance combination.
      #
      # == query output
      #
      #  emits columns:
      #    tag_id (int) -- the id of the tag
      #    provenance_id (int) -- the id of the provenance
      #    count (int) -- the number of audio events
      #    score_mean (numeric) -- the average score
      #    score_min (numeric) -- the minimum score
      #    score_max (numeric) -- the maximum score
      #    score_stdev (numeric) -- the standard deviation of scores
      #    consensus (numeric) -- the average consensus value
      #    verifications (int) -- the total number of verifications
      #
      class EventSummaryStatistics < Cte::NodeTemplate
        table_name :event_summary_statistics
        dependencies verification_consensus: Report::Ctes::EventSummary::VerificationConsensus
        select do
          verification_consensus.project(
            verification_consensus[:tag_id],
            verification_consensus[:provenance_id],
            verification_consensus[:audio_event_id].count.as('count'),
            verification_consensus[:score].average.as('score_mean'),
            verification_consensus[:score].minimum.as('score_min'),
            verification_consensus[:score].maximum.as('score_max'),
            verification_consensus[:score].std.as('score_stdev'),
            verification_consensus[:consensus_for_event].average.as('consensus'),
            verification_consensus[:total_verifications_for_event].sum.as('verifications')
          ).group(
            verification_consensus[:tag_id],
            verification_consensus[:provenance_id]
          )
        end
      end
    end
  end
end
