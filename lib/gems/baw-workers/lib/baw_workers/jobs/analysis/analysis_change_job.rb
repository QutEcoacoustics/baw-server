# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # Runs updates analysis job items on our queue.
      # Needs to be a background job because for large jobs the enqueue/cancelling
      # and database queries will take upwards of <unknown, maybe 60?> seconds.
      class AnalysisChangeJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.analysis_change.queue
        perform_expects Integer, Symbol

        class << self
          def retry(analysis_job)
            perform_later(analysis_job.id, :retry)
          end

          def suspend(analysis_job)
            perform_later(analysis_job.id, :suspend)
          end

          def resume(analysis_job)
            perform_later(analysis_job.id, :resume)
          end

          def enqueue(analysis_job)
            perform_later(analysis_job.id, :enqueue)
          end
        end

        # @return [::AnalysisJob] The database record for the current job
        attr_accessor :analysis_job

        def perform(analysis_job_id, action)
          self.analysis_job = AnalysisJob.find(analysis_job_id)

          case action
          when :retry
            retry_items
          when :suspend
            suspend_items
          when :resume
            resume_items
          when :enqueue
            enqueue_items
          else
            raise "Unknown action #{action}"
          end
        end

        # Suspends an analysis job by cancelling all queued items
        def suspend_items
          # get items
          query = AnalysisJobsItem.queued_for_analysis_job(analysis_job.id)

          # batch update
          query.find_in_batches do |items|
            items.each do |item|
              item.cancel! if item.may_cancel!
            end
          end
        end

        # Resumes an analysis job by converting cancelling or cancelled items to queued items
        def resume_items
          # get items
          query = AnalysisJobsItem.cancelled_for_analysis_job(analysis_job.id)

          # batch update
          query.find_in_batches do |items|
            items.each do |item|
              item.retry! if item.may_retry!
            end
          end
        end

        # Retry an analysis job by re-enqueuing all failed items
        def retry_items
          # get items
          query = AnalysisJobsItem.failed_for_analysis_job(analysis_job.id)

          # batch update
          query.find_in_batches do |items|
            items.each do |item|
              item.retry! if item.may_retry!
            end
          end
        end

        def enqueue_items
          query = AnalysisJobsItem.new_for_analysis_job(analysis_job.id)

          query.find_in_batches do |items|
            items.each do |item|
              item.queue! if item.may_queue!
            end
          end
        end
      end
    end
  end
end
