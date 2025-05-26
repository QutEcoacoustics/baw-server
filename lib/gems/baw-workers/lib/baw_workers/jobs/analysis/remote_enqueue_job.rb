# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # This is a regularly scheduled job that takes job items
      # from the analysis jobs items table and enqueues them in the batch analysis
      # queue. It is designed to allow us to throttle the number of jobs that are
      # enqueued in the remote queue at any one time.
      # It samples analysis jobs items with parity across multiple analysis jobs.
      class RemoteEnqueueJob < BawWorkers::Jobs::ApplicationJob
        BATCH_SIZE = 1000

        queue_as Settings.actions.analysis_remote_enqueue.queue
        perform_expects # nothing

        recurring_at Settings.actions.analysis_remote_enqueue.schedule

        # only allow one of these to run at once.
        # constrained resource: count of jobs on the remote queue.
        # It's ok to to discard because we expect this job to be regularly enqueued
        # by the scheduler.
        limit_concurrency_to 1, on_limit: :discard

        # Automatically retry jobs when we can't contact the remote queue
        # The block will also squash the exception on retry.
        retry_on ::PBS::Connection::TransportError, wait: 1.minute do |_job, error|
          push_message(error.message)
        end

        def perform
          # first check if we can contact the remote queue
          failed!('Could not connect to remote queue.') unless batch.remote_connected?

          # then query the remote queue for the limit of jobs that can be enqueued
          max = [maximum_queued_jobs, our_maximum].compact.min
          # then query the remote queue for the number of jobs that are currently enqueued
          current = currently_queued_jobs

          # adjust count for the number of remote jobs that are submitted
          # per analysis jobs item
          # e.g. 5000 pbs jobs, 1000 enqueued, 1 per submit
          #     5000 - 1000 = 4000
          # If not limit is set, we'll just use the current count - i.e. we can enqueue
          # as many as we like.
          submittable = max.nil? ? current : (max - current)

          completed!('Remote queue cannot accept any further jobs') if submittable < 1

          # get a list of analysis jobs items that are ready to be enqueued
          # - we'll sample across jobs to timeshare the remote enqueueing amongst jobs
          # - we'll only get batches that are ready to be enqueued - not a whole list
          #   enqueuing a small page at a time will limit memory leaks.
          # - we'll retrieve min(available, limit - current) items
          limit = [submittable, BATCH_SIZE].min

          # we only need one page of items - the next page will be picked up in
          # the next run of this job
          AnalysisJobsItem
            .sample_for_queueable_across_jobs(limit)
            .to_a => sampled

          completed!('Nothing left to enqueue') if sampled.empty?

          size = sampled.size
          report_progress(0, size)

          # then for each job item, attempt to enqueue it
          count = 0
          sampled.each do |item|
            success = logger.measure_debug("Enqueued analysis job item #{item.id}") {
              enqueue_item(item)
            }
            count += 1 if success

            report_progress(count, size)
          end

          logger.info('Enqueued', count:, of_batch_size: size)
          completed!("Enqueued #{count} of #{size} jobs, sleeping now")
        end

        # @param item_id [Integer]
        # @return [Boolean]
        def enqueue_item(item)
          # submits the job to the remote queue
          # and saves the record
          if item.may_queue?
            # slow warning: contacting remote system!
            item.queue!
          elsif item.may_retry?
            # slow warning: contacting remote system!
            item.retry!
          elsif item.queued?
            item.clear_transition_queue_or_retry
            item.save!
          else
            # we assume that whatever state we're in now that it will be resolved soon
            logger.warn(
              'Analysis job item is not in a queueable state. Ignoring.',
              item_id: item.id,
              status: item.status
            )
            false
          end
        end

        # @return [BawWorkers::BatchAnalysis::Communicator]
        def batch
          @batch ||= BawWorkers::Config.batch_analysis
        end

        def our_maximum
          [
            Settings.batch_analysis.remote_enqueue_limit,
            SiteSettings.batch_analysis_remote_enqueue_limit
          ].compact.first
        end

        def maximum_queued_jobs
          unwrap_result(batch.maximum_queued_jobs)
        end

        def currently_queued_jobs
          unwrap_result(batch.count_enqueued_jobs)
        end

        def unwrap_result(result)
          failed!(result.failure) if result.failure?

          result.value!
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_timestamp(self, 'RemoteEnqueueJob')
        end

        def name
          job_id
        end
      end
    end
  end
end
