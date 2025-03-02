# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # Extends any `ongoing` analysis jobs after a harvest has completed.
      # We don't even need to know what was harvested - the filter on the
      # analysis jobs will allow any new valid items to be included.
      class AmendAfterHarvestJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.analysis_amend_after_harvest.queue
        perform_expects Integer

        # @params harvest [Harvest] the harvest to amend.
        def self.enqueue(harvest)
          raise ArgumentError, 'harvest must be a Harvest' unless harvest.is_a?(::Harvest)
          raise ArgumentError, 'harvest must be be complete' unless harvest.complete? || harvest.streaming_harvest?

          perform_later(harvest.id)
        end

        def perform(harvest_id)
          harvest = ::Harvest.find(harvest_id)

          # for the audio recordings in the harvest
          # find the analysis jobs that are
          #   - system jobs that are ongoing
          #   - jobs that have a project_id that matches the harvest project_id
          #     and that are ongoing
          # and call amend on each one
          #

          jobs = [
            AnalysisJob.system_analyses.ongoing,
            AnalysisJob.where(project_id: harvest.project_id).ongoing
          ].flatten

          jobs.each_with_index do |analysis_job, index|
            report_progress(index + 1, jobs.size)
            amend_job(analysis_job)
          end
        end

        def create_job_id
          # Enqueue only one amend job per harvest.
          ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(
            self,
            {
              harvest: arguments&.first
            },
            'AmendAfterHarvestJob'
          )
        end

        def name
          job_id
        end

        private

        def amend_job(analysis_job)
          # this should be idempotent - if we fail we can safely retry
          Rails.logger.measure_info "Amended analysis job #{analysis_job.id}" do
            analysis_job.amend!
          end
        end
      end
    end
  end
end
