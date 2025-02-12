# frozen_string_literal: true

class AnalysisJob
  # state machine for `status` column of `AnalysisJobsItem`s.
  module StateMachine
    def self.included(base)
      base.include AASM

      # analysis_job lifecycle:
      #
      # 1. When a new analysis job is created, the state will be `preparing`.
      #    The new analysis job should be saved at this point.
      #    Note: no AnalysisJobsItems have been made.
      #
      # 2. Then the job must be started by transitioning to `processing`.
      #    We use a bulk sql statement to generate all the AnalysisJobsItems in
      #    one go. Then a background job (`BawWorkers::Jobs::Analysis::RemoteEnqueueJob`)
      #    enqueues the jobs on the remote batch analysis queue.
      #
      # 4. Then as each analysis job item is completed, it calls `check_progress!`
      #    which checks if the job `may_complete?`. If
      #    so then the job transitions to `completed`. Users are notified with
      #     an email and the job is marked as completed.
      #
      # Additional transitions:
      #
      # Suspend:
      #   Transitioning to `suspended` will mark all AnalysisJobsItems as
      #   `cancel` (via the `transition` column). Then a background job
      #   (`BawWorkers::Jobs::Analysis::RemoteCancelJob`) will be enqueued
      #   to remove items from the remote queue.
      #
      # Resume:
      #   Transitioning back to `processing` from `suspended`. When resumed, all
      #   items that are not complete are marked as `retry` via the `transition`
      #   column. Then a background job (`BawWorkers::Jobs::Analysis::RemoteEnqueueJob`)
      #   will add the items back to the remote queue.
      #
      # Retry:
      #   Allows transitioning from `completed` to `processing` if there are any
      #   failed items. All failed items are marked as `retry` via the `transition`
      #   column. Then a background job (`BawWorkers::Jobs::Analysis::RemoteEnqueueJob`)
      #   will add the items back to the remote queue.
      #
      # Amend:
      #   Only allowed for jobs that are `ongoing`, `amend` allows for moving
      #   back to the `processing` state. The main use case is to add new audio
      #   recordings to an existing job and this is done by the same bulk sql
      #   statement as the initial `processing` transition. Since the statement
      #   is an upsert, it is idempotent for existing items and will not affect
      #   their state.
      #
      # State transition map:
      #
      #                     _____________
      #                    ↓ ↑           ↑
      # :preparing → :processing ←→ :completed
      #                    ↓ ↑
      #                :suspended
      base.aasm column: :overall_status, no_direct_assignment: true, whiny_persistence: true do
        # @!method preparing?
        # @return [Boolean] true if the job is preparing
        # only the before_enter callback works on the initial state
        state :preparing, initial: true, before_enter: [
          :update_status_timestamp,
          :update_overall_stats
        ]

        # @!method processing?
        # @return [Boolean] true if the job is processing
        state :processing, before_enter: :validate_has_items
        # @!method suspended?
        # @return [Boolean] true if the job is suspended
        state :suspended
        # @!method completed?
        # @return [Boolean] true if the job has completed
        # completed just means all processing has finished, whether it succeeds or not.
        state :completed, after_enter: :send_completed_email

        # @!method may_process?
        #   @return [Boolean] true if the job may be processed
        # @!method process!
        #   process the job
        #   @return [Boolean]
        event :process, guard: :id_present? do
          transitions(
            from: :preparing,
            to: :processing,
            after: [:generate_analysis_job_items, :update_overall_stats],
            success: :send_new_job_email
          )
        end

        # @!method may_complete?
        #   @return [Boolean] true if the job may be completed
        # @!method complete!
        #   complete the job
        #   @return [Boolean]
        event :complete, guard: :all_job_items_completed? do
          transitions from: :processing, to: :completed
        end

        # @!method may_suspend?
        #   @return [Boolean] true if the job may be suspended
        # @!method suspend!
        #   suspend the job
        #   @return [Boolean]
        event :suspend do
          transitions(
            from: :processing,
            to: :suspended,
            after: :suspend_job
          )
        end

        # @!method may_resume?
        #   @return [Boolean] true if the job may be resumed
        # @!method resume!
        #   resume the job
        #   @return [Boolean]
        event :resume do
          transitions(
            from: :suspended,
            to: :processing,
            after: :resume_job
          )
        end

        # @!method may_retry?
        #   @return [Boolean] true if the job may be retried
        # @!method retry!
        #   retry just the failures
        #   @return [Boolean]
        event :retry do
          transitions(
            from: [:processing, :completed],
            to: :processing,
            guard: :are_any_job_items_failed?,
            after: [:retry_job, :send_retry_email]
          )
        end

        # @!method may_amend?
        #   @return [Boolean] true if the job may be amended
        # @!method amend!
        #   amend the job - add audio recordings that now match filter but were
        #   not included originally.
        #   @return [Boolean]
        event :amend, guard: :ongoing? do
          transitions(
            from: [:processing, :completed],
            to: :processing,
            after: [:amend_job, :generate_analysis_job_items, :update_overall_stats]
          )
        end

        after_all_transitions :update_status_timestamp
      end
    end

    private

    #
    # guards for the state machine
    #

    def id_present?
      !id.nil?
    end

    def all_job_items_completed?
      ActiveRecord::Base.uncached do
        items_count = AnalysisJobsItem.for_analysis_job(id).count
        completed_count = AnalysisJobsItem.completed_for_analysis_job(id).count
        transition_count = AnalysisJobsItem.for_analysis_job(id).where.not(transition: nil).count

        # is every result completed?
        # but also check that we're waiting for no more work to be done
        # (edge case: all items can be completed part-way through a retry attempt)
        items_count == completed_count && transition_count.zero?
      end
    end

    def are_any_job_items_failed?
      AnalysisJobsItem.failed_for_analysis_job(id).count.positive?
    end

    def ongoing?
      ongoing
    end

    #
    # callbacks for the state machine
    #

    def send_new_job_email
      AnalysisJobMailer.new_job_message(self, nil).deliver_later
    end

    def generate_analysis_job_items
      # the RemoteEnqueueJob is scheduled and processes these items automatically
      count = AnalysisJobsItem.batch_insert_items_for_job(self)
      Rails.logger.debug { "Created #{count} analysis job items for job #{id}" }
    end

    def validate_has_items
      count = analysis_jobs_items.count

      return unless count.zero?

      errors.add(:base, 'Analysis job has no items')
    end

    def send_completed_email
      AnalysisJobMailer.completed_job_message(self, nil).deliver_later
    end

    # Suspends an analysis job by cancelling all queued items
    def suspend_job
      AnalysisJobsItem.batch_mark_items_to_cancel_for_job(self)

      # do the cancelling on the background
      BawWorkers::Jobs::Analysis::RemoteCancelJob.enqueue(self)
      self.suspend_count += 1
    end

    # Resumes an analysis job by converting cancelling or cancelled items to queued items
    def resume_job
      # the RemoteEnqueueJob is scheduled and processes these items automatically
      AnalysisJobsItem.batch_retry_items_for_job(self)
      self.resume_count += 1
    end

    # Retry an analysis job by re-enqueuing all failed items
    def retry_job
      # the RemoteEnqueueJob is scheduled and processes these items automatically
      AnalysisJobsItem.batch_retry_items_for_job(self)
      self.retry_count += 1
    end

    def amend_job
      self.amend_count += 1
    end

    def send_retry_email
      AnalysisJobMailer.retry_job_message(self, nil).deliver_later
    end

    # Update status timestamp whenever a transition occurs.
    # Does not persist changes - happens before aasm save.
    def update_status_timestamp
      self.overall_status_modified_at = Time.zone.now
    end

    def update_overall_stats
      stats = overall_statistics_query
      self.overall_count = stats[:overall_count].to_i
      self.overall_duration_seconds = stats[:overall_duration_seconds]
      self.overall_data_length_bytes = stats[:overall_data_length_bytes].to_i
    end
  end
end
