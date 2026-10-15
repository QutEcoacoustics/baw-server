# frozen_string_literal: true

class Export
  # Status transitions for an Export.
  #
  # pending -> queued -> working -> ready
  #    \         \          \
  #     '---------'----------'--> failed -> queued
  #
  # A purged export is `ready` without a file and can also be queued again.
  #
  # Requires the including model to define the `STATUS_*` constants.
  module StateMachine
    # Raised when an invalid state transition is attempted.
    class InvalidTransition < StandardError; end

    private

    def queued!
      from = [STATUS_PENDING, STATUS_FAILED]
      from << STATUS_READY if purged?
      validate_transition(from:, to: STATUS_QUEUED)

      update!(status: STATUS_QUEUED, error: nil, finished_at: nil, purged: false)
    end

    def working!(resume: false)
      from = [STATUS_PENDING, STATUS_QUEUED, STATUS_FAILED]
      from << STATUS_WORKING if resume
      validate_transition(from:, to: STATUS_WORKING)

      update!(
        status: STATUS_WORKING,
        started_at: Time.current,
        error: nil,
        finished_at: nil
      )
    end

    def ready!
      validate_transition(from: [STATUS_WORKING], to: STATUS_READY)
      raise InvalidTransition, 'Cannot finish an export without a file' unless file.attached?

      update!(
        status: STATUS_READY,
        finished_at: Time.current,
        error: nil
      )
    end

    # Records a failed export.
    #
    # Uses update_columns to skip validations and callbacks, and rescues any
    # persistence error so the caller's original exception is not replaced.
    def record_failure!(message)
      # rubocop:disable Rails/SkipsModelValidations -- skipping validations is the point
      update_columns(
        status: STATUS_FAILED,
        error: message,
        finished_at: Time.current,
        updated_at: Time.current
      )
      # rubocop:enable Rails/SkipsModelValidations
    rescue StandardError => e
      logger.error('Failed to record export failure', e)
    end

    # Validates that a state transition is allowed.
    #
    # @param from [Array<String>] The allowed current states.
    # @param to [String] The target state.
    # @raise [InvalidTransition] If the transition is not allowed.
    def validate_transition(from:, to:)
      raise InvalidTransition, "Cannot transition from #{status} to #{to}" unless from.include?(status)
    end
  end
end
