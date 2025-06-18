# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # This is a regularly scheduled job that takes job items
      # from the analysis jobs items table and checks their status.
      # This job does the final status check for items that have been marked as
      # transition finished (via a webhook).
      class RemoteStatusCheckJob < BawWorkers::Jobs::ApplicationJob
        BATCH_SIZE = 1000

        queue_as Settings.actions.analysis_status_check.queue
        perform_expects # nothing

        recurring_at Settings.actions.analysis_status_check.schedule

        # only allow one of these to run at once.
        # constrained resource: don't want two of these running at once otherwise
        # we'll get race conditions when updating the status of items.
        # TODO: lock the items? pg row lock, SELECT FOR SHARE, and then SKIP LOCKED
        # It's ok to to discard because we expect this job to be regularly enqueued
        # by the scheduler.
        limit_concurrency_to 1, on_limit: :discard

        # Automatically retry jobs when we can't contact the remote queue
        # The block will also squash the exception on retry.
        retry_on ::PBS::Errors::TransportError, wait: 1.minute do |_job, error|
          push_message(error.message)
        end

        discard_on ::PBS::Errors::TransientError do |job, error|
          # If we get a transient error, we can discard the job.
          # This is because the job will be retried by the scheduler.
          job.push_message("Discarding job due to transient error: #{error.message}")
          logger.warn(
            'Discarding job due to transient error',
            error: error.message
          )
        end

        def perform
          # first check if we can contact the remote queue
          failed!('Could not connect to remote queue.') unless batch.remote_connected?

          # find items that are marked to finish
          item_ids = AnalysisJobsItem
            .transition_finish
            .order(created_at: :asc)
            # don't do too many at once - dodgy memory management
            .take(BATCH_SIZE)
            # delay loading items until we need them
            .pluck(:id)
            .to_a

          completed!('Nothing left to finish') if item_ids.empty?

          total = item_ids.size
          report_progress(0, total)

          # then for each job item check it
          item_ids.each_with_index do |item_id, index|
            logger.measure_debug("Attempting to finish analysis job item #{item_id}") do
              check_item(item_id)
            end

            report_progress(index + 1, total) if (index % 10).zero?
          end

          completed!("Finished #{total} jobs, sleeping now")
        end

        # @param item_id [Integer]
        # @return [Boolean]
        def check_item(item_id)
          item = AnalysisJobsItem.find(item_id)

          if item.may_finish?
            item.finish!
          else
            item.clear_transition_finish
            item.save!
          end
        # https://github.com/QutEcoacoustics/baw-server/issues/765
        rescue ::PBS::Errors::InvalidStateError => e
          # In this case we just keep processing the batch, and the next round of status checks will catch the job
          logger.warn('Remote job is not ready to be finished, wait for next execution', exception: e, item_id: item.id)
          push_message(
            "Remote job is not ready to be finished, wait for next execution: #{e.message}, item_id: #{item.id}"
          )
          false
        end

        # @return [BawWorkers::BatchAnalysis::Communicator]
        def batch
          @batch ||= BawWorkers::Config.batch_analysis
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_timestamp(self, 'RemoteStatusCheckJob')
        end

        def name
          job_id
        end
      end
    end
  end
end
