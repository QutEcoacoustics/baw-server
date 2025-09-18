# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      # Statistics per tag/prevenance for audio events
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
