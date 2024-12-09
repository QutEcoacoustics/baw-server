# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # This is a regularly scheduled job that takes job items
      # from the analysis jobs items table and checks their status.
      # This job a backup mechanism that checks job status in case
      # our web hooks fail (e.g. transition: finish is not set).
      class RemoteStaleCheckJob < BawWorkers::Jobs::ApplicationJob
        BATCH_SIZE = 1000

        queue_as Settings.actions.analysis_stale_check.queue
        perform_expects [NilClass, Integer]

        recurring_at Settings.actions.analysis_stale_check.schedule

        # only allow one of these to run at once.
        # constrained resource: don't want two of these running at once otherwise
        # we'll get race conditions when updating the status of items.
        # TODO: lock the items? pg row lock, SELECT FOR SHARE, and then SKIP LOCKED
        # It's ok to to discard because we expect this job to be regularly enqueued
        # by the scheduler.
        limit_concurrency_to 1, on_limit: :discard

        # Automatically retry jobs when we can't contact the remote queue
        # The block will also squash the exception on retry.
        retry_on ::PBS::Connection::TransportError, wait: 1.minute do |_job, error|
          push_message(error.message)
        end

        def perform(min_age_seconds = nil)
          # first check if we can contact the remote queue
          failed!('Could not connect to remote queue.') unless batch.remote_connected?

          # we only need one page of items - the next page will be picked up in
          # the next run of this job
          age = (min_age_seconds || Settings.actions.analysis_stale_check.min_age_seconds).seconds.ago
          item_ids = AnalysisJobsItem
            .stale_across_jobs(BATCH_SIZE, stale_after: age)
            # delay loading items until we need them
            .pluck(:id)
            .to_a

          completed!('Nothing left to check') if item_ids.empty?

          total = item_ids.size
          report_progress(0, total)

          # then for each job item check it
          stale_count = 0
          item_ids.each_with_index do |item_id, index|
            stale = logger.debug("Checking analysis job item #{item_id}") {
              check_item(item_id)
            }

            stale_count += 1 if stale

            report_progress(index, total)
          end

          completed!("Checked #{total} jobs, #{stale_count} were marked as finished, sleeping now")
        end

        # @param item_id [Integer]
        # @return [Boolean]
        def check_item(item_id)
          item = AnalysisJobsItem.find(item_id)

          return false unless item.queued? || item.working?

          # fetch a status update from the remote queue
          status = batch.job_status(item)

          # Two cases we want to recover from:
          # - The job is finished, but we didn't get the web hook.
          # - The job is so old that is has be removed from the remote queues status tracking.
          if status.finished? || status.not_found?
            # pass along the status so we don't double query for this job
            item.finish!(status)
          else
            # noop do nothing, item is in queue, and still healthy
            false
          end
        end

        # @return [BawWorkers::BatchAnalysis::Communicator]
        def batch
          @batch ||= BawWorkers::Config.batch_analysis
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_timestamp(self, 'RemoteStaleCheckJob')
        end

        def name
          job_id
        end
      end
    end
  end
end
