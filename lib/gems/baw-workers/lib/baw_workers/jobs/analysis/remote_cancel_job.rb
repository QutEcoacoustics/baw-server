# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # Removes items from the remote queue for an analysis job.
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
        retry_on ::PBS::Connection::TransportError, wait: 1.minute do |_job, error|
          push_message(error.message)
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

          loop do
            logger.debug('querying for items to change state')

            # @type [Array<Integer>]
            batch = AnalysisJobsItem.fetch_cancellable(analysis_job).pluck(:id)
            total = batch.count

            if batch.empty?
              completed!('Nothing found to cancel')

              # this break should be redundant since the above throws
              break
            end

            push_message("Found batch of items to cancel, count: #{total}")

            batch.each_with_index do |id, index|
              cancel_item(id)

              report_progress(index, total)
            end
          end
        end

        def cancel_item(id)
          # @type [AnalysisJobsItem]
          item = AnalysisJobsItem.find(id)

          if item.may_cancel?
            # slow warning: contacting remote system!
            item.cancel!
          elsif item.cancelled?
            # we're already in our desired state
            item.clear_transition_cancel
            item.save!
          end
        end
      end
    end
  end
end
