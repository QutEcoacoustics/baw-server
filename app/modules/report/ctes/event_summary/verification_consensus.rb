# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      # Calculate consensus for each event
      # Selects the maximum value of the ratio for each group: this is the
      # consensus for a given audio event
      class VerificationConsensus < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :verification_consensus
        depends_on verification_count: Report::Ctes::EventSummary::VerificationCount
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
