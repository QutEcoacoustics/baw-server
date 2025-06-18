# frozen_string_literal: true

module PBS
  module Errors
    # A transient error that indicates that a PBS command can not contact the PBS server for some reason.
    class ConnectionRefusedError < TransientError
      CONNECTION_REFUSED_REGEX = /.*Connection refused.*/

      # Basically wraps an error string in a class so we can match on it easily elsewhere
      # @param result [PBS::Result] the result from a SSH command that failed
      # @return [ConnectionRefusedError, nil] a new instance if the error matches, otherwise nil
      def self.wrap(result)
        return unless CONNECTION_REFUSED_REGEX.match?(result.stderr)

        new(result.to_s)
      end
    end
  end
end
