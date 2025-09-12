# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # Imports result sets generated from batch analysis jobs.
      class ImportResultsJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.analysis_import_results.queue
        perform_expects Integer

        # @params analysis_jobs_item [AnalysisJobsItem] the item to import results for.
        def self.enqueue(analysis_jobs_item)
          perform_later(analysis_jobs_item.id)
        end

        def perform(analysis_jobs_item_id)
          item = AnalysisJobsItem
            # Apparently Bullet tells me we don't need to eager load this?
            #.includes([:analysis_job, :audio_recording, :script])
            .find(analysis_jobs_item_id)

          # check if the item is ready to import
          unless item.result_success?
            # item is not ready to import
            failed!("Item is not ready to import, status is `#{item.result}`")
          end

          # import the results
          result = item.import_results!

          if result.failure?
            item.import_success = false
            item.append_error(result.failure.join(".\n"))
            item.save!
            # we used to call `failed!` here - but that's not accurate. Bad data is not the same as the job failing.
            completed!(*result.failure)
          else
            item.import_success = true
            item.save!
          end
        end

        def create_job_id
          # Enqueue only one import job per item.
          ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(
            self,
            {
              item: arguments&.first
            },
            'ImportResultsJob'
          )
        end

        def name
          job_id
        end
      end
    end
  end
end
