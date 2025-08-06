# frozen_string_literal: true

module Report
  module Ctes
    module EventSummary
      # Count verifications per tag/provenance/audio_event/confirmed
      # Calculates category_count and ratio for each group
      # one row per tag/provenance/audio_event/'confirmed category'
      # category_count is calculated as per grouping and would give tuples like:
      #   { confirmed: correct, category_count: 1 }
      #   { confirmed: incorrect, category_count: 1 }
      # ratio is the ratio of category_count to total_count, for each group
      class VerificationCount < Report::Cte::Node
        include Report::Cte::Dsl
        table_name :verification_count
        depends_on base_verification: Report::Ctes::BaseVerification
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
