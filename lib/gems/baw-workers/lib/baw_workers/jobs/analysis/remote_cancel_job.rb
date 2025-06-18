# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # Removes *all* items from the remote queue for an analysis job.
      class RemoteCancelJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.analysis_cancel_items.queue
        perform_expects Integer

        # only allow one of these to run at once, per analysis job
        # constrained resource: analysis job items per analysis job (database)
        limit_concurrency_to 1, on_limit: :retry do |job|
          # analysis job id
          job.arguments[0]
        end

        # Automatically retry jobs when we can't contact the remote queue
        # The block will also squash the exception on retry.
        retry_on ::PBS::Errors::TransportError, wait: 1.minute do |_job, error|
          push_message(error.message)
        end

        retry_on ::PBS::Errors::TransientError, wait: 1.minute, attempts: :unlimited do |job, error|
          # If we get a transient error, we can retry the job.
          # This is because the job will be retried by the scheduler.
          job.push_message("Retrying job due to transient error: #{error.message}")
        end

        # very aggressive retrying
        #retry_on StandardError, attempts: 10, wait: :exponentially_longer

        class << self
          # Enqueues a change state job for an analysis job.
          # It will handle retrying or cancelling items as required.
          # @param [AnalysisJob] analysis_job
          def enqueue(analysis_job)
            perform_later(analysis_job.id)
          end
        end

        def create_job_id
          # We want to be able to enqueue multiple change state jobs for the same
          # analysis job.
          # The concurrency module will make sure they don't run at the same time.
          # Any duplicate jobs will act as a safe guard to clean up any items
          # after any other change state job has run.
          ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(
            self,
            {
              job: arguments&.first,
              t: ::BawWorkers::ActiveJob::Identity::Generators.now_to_s
            },
            'RemoteCancelJob'
          )
        end

        def name
          job_id
        end

        def perform(analysis_job_id)
          analysis_job = AnalysisJob.find(analysis_job_id)

          result = fast_cancel(analysis_job)
          if result.success?
            count = result.value!
            report_progress(count, count)
            completed!("Batch cancelled #{result.value!} items")
          end

          push_message('Failed to batch cancel. Slow cancelling items one by one.')

          total = 0
          counter = 0
          loop do
            logger.debug('querying for items to change state')

            # @type [Array<Integer>]
            batch = AnalysisJobsItem.fetch_cancellable(analysis_job).pluck(:id)
            total += batch.count
            report_progress(counter, total)

            completed!('Nothing found to cancel') if batch.empty?

            push_message("Found batch of items to cancel, count: #{total}")

            batch.each do |id|
              cancel_item(id)

              counter += 1

              report_progress(counter, total) if (counter % 100).zero?
            end

            report_progress(counter, total)
          end
        end

        # Cancels all analysis job items in a job.
        # @param [AnalysisJob] analysis_job
        # @return [Dry::Monads::Result]
        def fast_cancel(analysis_job)
          AnalysisJobsItem.cancel_items!(analysis_job)
        end

        def cancel_item(id)
          # @type [AnalysisJobsItem]
          item = AnalysisJobsItem.find(id)

          if item.may_cancel?
            # slow warning: contacting remote system!
            item.cancel!
          else
            # we're already in our desired state
            item.clear_transition_cancel
            item.save!
          end
        end
      end
    end
  end
end
