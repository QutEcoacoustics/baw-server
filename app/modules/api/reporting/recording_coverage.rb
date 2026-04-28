# frozen_string_literal: true

module Api
  module Reporting
    # Report template with the required CTEs and joins to produce a report of
    # recording coverage. Coverage is calculated as the total period covered by
    # contiguous group of recordings separated by gaps smaller than a calculated
    # threshold. Density is reported as the ratio of actual time covered to the
    # total covered period for the group.
    #
    # Implements #call(query) for use as a template in execute_report.
    class RecordingCoverage
      include CteHelper

      def call(query)
        query.arel
      end
    end
  end
end
