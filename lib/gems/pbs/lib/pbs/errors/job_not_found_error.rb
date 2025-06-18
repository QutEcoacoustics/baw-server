# frozen_string_literal: true

require_relative 'command_error'

module PBS
  module Errors
    # An error that indicates that a PBS command could not find a job
    class JobNotFoundError < CommandError
      JOB_NOT_FOUND_REGEX = /.*Unknown Job Id (#{::PBS::Connection::JOB_ID_REGEX})/

      attr_reader :job_id

      # Basically wraps an error string in a class so we can match on it easily elsewhere
      # @param result [PBS::Result] the result from a SSH command that failed
      # @return [JobNotFoundError, nil] a new instance if the error matches, otherwise nil
      def self.wrap(result)
        match = JOB_NOT_FOUND_REGEX.match(result.stderr)

        return unless match

        # Extract the job id from the error message
        job_id = match[1].strip
        new(result.to_s, job_id)
      end

      def initialize(stderr, job_id)
        super(stderr)
        @job_id = job_id
      end
    end
  end
end
