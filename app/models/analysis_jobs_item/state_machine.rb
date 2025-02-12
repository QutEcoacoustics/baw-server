# frozen_string_literal: true

class AnalysisJobsItem
  # state machine for `status` column of `AnalysisJobsItem`s.
  module StateMachine
    STATUS_NEW = 'new'
    STATUS_QUEUED = 'queued'
    STATUS_WORKING = 'working'
    STATUS_FINISHED = 'finished'
    STATUS_NEW_SYM = :new
    STATUS_QUEUED_SYM = :queued
    STATUS_WORKING_SYM = :working
    STATUS_FINISHED_SYM = :finished

    def self.included(base)
      base.include AASM

      # we can't use Instance_methods: false because it's not in our version
      # of rails. So we're just going to add a junk prefix so we don't have
      # conflicts with the aasm predicates.
      base.enum :status, {
        STATUS_NEW_SYM => STATUS_NEW,
        STATUS_QUEUED_SYM => STATUS_QUEUED,
        STATUS_WORKING_SYM => STATUS_WORKING,
        STATUS_FINISHED_SYM => STATUS_FINISHED
      }, prefix: :status, default: STATUS_NEW

      # State transition map
      #           -----------------------
      #           ↓                     |
      # :new → :queued → :working → :finished
      #   |       |           |         ↑
      #   -------------------------------
      #
      # When :finished a `result` is set:
      #
      # - :success
      # - :failed: the script or a command within failed
      # - :killed: the script was killed by the system for exceeding a resource limit
      # - :cancelled: the server terminated a job before it finished
      #
      # Most of the transitions are not meant to be called in web request but
      # rather in a background job. This is because any access to the remote
      # queue can be very high latency.
      #
      # Safe/quick/web transitions:
      #   - :work (:queued → :working)
      #
      # Slow/background worker transitions:
      #
      #   - :queue (:new → :queued)
      #   - :cancel (* → :finish)
      #   - :finish (:working → :finished)
      #   - :retry (:finished → :queued)
      #
      # Background worker transitions are signalled by setting the `transition`
      # column to the desired transition. Then a background job will process
      # the transition. Pending transitions are processed by the following jobs:
      #
      #  - :finish: RemoteStatusJob
      #  - :cancel: RemoteCancelJob
      #  - :queue and :retry: RemoteEnqueueJob
      #
      # The following transitions can be set (via API):
      #
      #   - :work (direct transition)
      #   - :finish (set transition column to :finish)
      #
      # Architecture notes:
      #
      #   - Using a `transition` column allows us to apply changes in bulk. This
      #     makes operations like adding new items, or cancelling all items, quick
      #     enough to do in one transaction avoiding long web requests. A background
      #     worker can then process items slowly, transforming them through the
      #     expensive state machine.
      #   - The alternative to the transition column is bulk updating the status
      #     column. This would bypass the state machine though (and all the safety)
      #     and would also require intermediate states (before and after versions
      #     of each state).
      #     It also makes race conditions rarer.
      #   - We used to model the result enum as states in the state machine.
      #     This however conflated the working state of the job with the result.
      #     It was also difficult to model terminal states for which a result was
      #     not yet available - a distinct issue in PBS where the running script
      #     has no idea of it's result until after completion.
      #   - Upon entering the :finished state, we:
      #     1. Do a status check
      #     2. Apply the remote job status
      #     3. Clear the tracking history from the remote queue
      #     4. Then clear our copy of the queue_id.
      #     - It is important because even finished remote jobs use resources on
      #       the remote queue. We want to free those resources as soon as possible.
      #     - But we also need to query the remote queue for a status update **first**
      #       to set the result!
      #
      base.aasm column: :status, enum: true, no_direct_assignment: true, whiny_persistence: true do
        # @!method new?
        #   @return [Boolean] true if the item has is new
        state STATUS_NEW_SYM, initial: true
        # When this item is enqueued on the remote queue
        # @!method queued?
        #   @return [Boolean] true if the item has is queued
        state(
          STATUS_QUEUED_SYM,
          before_enter: :add_to_queue,
          enter: [
            :set_queued_at,
            :increment_attempts
          ]
        )
        # @!method working?
        #   @return [Boolean] true if the item has is working
        state STATUS_WORKING_SYM, enter: :set_work_started_at

        # @!method finished?
        #   @return [Boolean] true if the item has finished
        state STATUS_FINISHED_SYM, enter: [
          :set_finished_at,
          :apply_remote_job_status,
          :clear_from_queue,
          :clear_queue_id
        ], after_enter: [
          :increment_statistics,
          :check_overall_progress,
          :enqueue_import_results
        ]

        # @!method queue!
        #  @return [Boolean]
        # @!method may_queue?
        #  @return [Boolean] true if the item can be queued
        event :queue, guards: [:not_cancelled?] do
          transitions(
            from: STATUS_NEW_SYM,
            to: STATUS_QUEUED_SYM,
            after: [:clear_transition_queue]
          )
        end

        # @!method work!
        #  @return [Boolean]
        # @!method may_work?
        #  @return [Boolean] true if the item can be worked on
        event :work do
          transitions from: STATUS_QUEUED_SYM, to: STATUS_WORKING_SYM
        end

        # @!method finish!(status = nil)
        #  @param status [::BawWorkers::BatchAnalysis::Models::JobStatus] a job status payload
        #   from the remote queue. Sometimes we need to query the remote queue more
        #   than once to get the final status and we want to reuse the same status.
        #  @return [Boolean]
        event :finish do
          # there is a conceivable case where we never get the working status update
          transitions(
            from: [STATUS_QUEUED_SYM, STATUS_WORKING_SYM, STATUS_FINISHED_SYM],
            to: STATUS_FINISHED_SYM,
            after: [:clear_transition_finish]
          )
        end

        # @!method cancel!
        #  Cancels the job item.
        #  ! Must be kept in sync with AnalysisJobsItem.cancel_items!
        #  @return [Boolean]
        # @!method may_cancel?
        #  @return [Boolean] true if the item can be cancelled
        event :cancel do
          transitions(
            from: [STATUS_QUEUED_SYM, STATUS_WORKING_SYM, STATUS_NEW_SYM],
            to: STATUS_FINISHED_SYM,
            after: [:remove_from_queue, :clear_transition_cancel, :set_result_cancelled]
          )
        end

        # @!method retry!
        # @!method may_retry?
        #  @return [Boolean] true if the item can be retried
        event :retry do
          transitions(
            from: STATUS_FINISHED_SYM,
            to: STATUS_QUEUED_SYM,
            after: [:clear_error, :clear_result, :clear_transition_retry]
          )
        end
      end
    end

    private

    #
    # state machine guards
    #

    def not_cancelled?
      !transition_cancel?
    end

    def failed?
      FAILED_RESULTS.include?(result)
    end

    #
    # state machine callbacks
    #

    # Enqueue this item representing an audio recordings to a asynchronous processing queue.
    # On error attempts to re-enqueue the job three times.
    # Will raise on failure.
    def add_to_queue
      # we let failures bubble up. The RemoteEnqueueJob should catch and then retry
      result = BawWorkers::Config.batch_analysis.submit_job(self)

      # the assumption here is that result is a unique identifier that we can
      # later use to interrogate the message queue
      self.queue_id = result.value!
    end

    # Dequeue this item representing an audio recordings to a remote queue.
    # Will raise on failure.
    def remove_from_queue
      return if queue_id.blank?

      BawWorkers::Config.batch_analysis.cancel_job(self).value!
    end

    # Remove the job history from the queue.
    # It's important to do this as soon as possible to free up resources on the
    # remote queue.
    def clear_from_queue
      BawWorkers::Config.batch_analysis.clear_job(self).value!
    end

    def check_overall_progress
      analysis_job.check_progress!
    end

    def enqueue_import_results
      return unless result_success?

      BawWorkers::Jobs::Analysis::ImportResultsJob.enqueue(self)
    end

    def clear_queue_id
      self.queue_id = nil
    end

    def set_queued_at
      self.queued_at = Time.zone.now
    end

    def increment_attempts
      self.attempts = (attempts || 0) + 1
    end

    def set_work_started_at
      self.work_started_at = Time.zone.now
    end

    def set_finished_at
      self.finished_at = Time.zone.now
    end

    def clear_error
      self.error = nil
    end

    def clear_result
      self.result = nil
    end

    def set_result_cancelled
      # this is needed for the new-> finished (cancelled) transition since result can't be
      # set by apply_remote_job_status
      self.result = RESULT_CANCELLED
    end

    def increment_statistics
      # technically we could increment on any result (the counters are named
      # analyses_completed after all), but it would be pretty disingenuous to
      # increment on a failure
      return unless result_success?

      Statistics::UserStatistics.increment_analysis_count(
        analysis_job.creator,
        duration: audio_recording.duration_seconds
      )
      Statistics::AudioRecordingStatistics.increment_analysis_count(audio_recording)
    end
  end
end
