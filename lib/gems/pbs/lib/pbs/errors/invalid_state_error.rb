# frozen_string_literal: true

module PBS
  module Errors
    # Detected while trying to delete a job that is finishing
    class InvalidStateError < TransientError
      INVALID_STATE_REGEX = /.*Request invalid for state of job.*/

      # Wraps an error string in a class so we can match on it easily elsewhere
      # @param result [PBS::Result] the result from a SSH command that failed
      # @return [InvalidStateError, nil] a new instance if the error matches, otherwise nil
      def self.wrap(result)
        return unless result.stderr.match?(INVALID_STATE_REGEX)

        new(result.to_s)
      end
    end
  end
end
