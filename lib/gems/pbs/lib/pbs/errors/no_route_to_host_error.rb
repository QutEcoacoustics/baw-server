# frozen_string_literal: true

module PBS
  module Errors
    # A transient error that indicates that a PBS command cannot reach the host.
    class NoRouteToHostError < TransientError
      NO_ROUTE_TO_HOST_REGEX = /.*No route to host.*/

      # Basically wraps an error string in a class so we can match on it easily elsewhere
      # @param result [PBS::Result] the result from a SSH command that failed
      # @return [NoRouteToHostError, nil] a new instance if the error matches, otherwise nil
      def self.wrap(result)
        return unless NO_ROUTE_TO_HOST_REGEX.match?(result.stderr)

        new(result.to_s)
      end
    end
  end
end
