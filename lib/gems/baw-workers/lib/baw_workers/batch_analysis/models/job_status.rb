# frozen_string_literal: true

module BawWorkers
  module BatchAnalysis
    module Models
      # An abstract representation of the status of a job.
      # Also can represent failing to find a job.
      class JobStatus < ::Dry::Struct
        STATUS_FINISHED = :finished
        STATUS_RUNNING = :running
        STATUS_QUEUED = :queued
        STATUS_NOT_FOUND = :not_found

        RESULT_SUCCESS = :success
        RESULT_FAILED = :failed
        RESULT_KILLED = :killed
        RESULT_CANCELLED = :cancelled

        # @!attribute [r] status
        #   The status of the job (but not whether it was successful or not)
        #   @return [Symbol]
        attribute :status, ::BawWorkers::Dry::Types::Coercible::Symbol.enum(
          STATUS_FINISHED, STATUS_RUNNING, STATUS_QUEUED, STATUS_NOT_FOUND
        )

        # @!attribute [r] result
        #   The success state of the job. Matches the [AnalysisJobsItem::RESULT_*] constants.
        #   @return [Symbol,nil]
        attribute :result, ::BawWorkers::Dry::Types::Coercible::Symbol.enum(
          RESULT_SUCCESS, RESULT_FAILED, RESULT_KILLED, RESULT_CANCELLED
        ).optional.default(nil)

        # @!attribute [r] error
        #   @return [String]
        attribute :error, ::BawWorkers::Dry::Types::String.optional.default(nil)

        # @!attribute [r] job_id
        #   @return [String]
        attribute :job_id, ::BawWorkers::Dry::Types::String.optional.default(nil)

        # @!attribute [r] used_walltime_seconds
        #   @return [Integer]
        attribute :used_walltime_seconds, ::BawWorkers::Dry::Types::Integer.optional.default(nil)

        # @!attribute [r] used_memory_bytes
        #   @return [Integer]
        attribute :used_memory_bytes, ::BawWorkers::Dry::Types::Integer.optional.default(nil)

        # @!attribute [r] raw
        #   @return [Object]
        attribute :raw, ::BawWorkers::Dry::Types::Any

        def finished?
          status == STATUS_FINISHED
        end

        def running?
          status == STATUS_RUNNING
        end

        def queued?
          status == STATUS_QUEUED
        end

        # True when the job status was not found on the remote server.
        # This doesn't indicate a failure, just that the job status was not found.
        def not_found?
          status == STATUS_NOT_FOUND
        end

        def successful?
          result == RESULT_SUCCESS
        end

        def failed?
          result == RESULT_FAILED
        end

        def killed?
          result == RESULT_KILLED
        end

        def cancelled?
          result == RESULT_CANCELLED
        end

        # Create a generic status from a remote queue status.
        # @param type [Symbol] The type of job status.
        # @param value [::Dry::Monads::Result<Hash>]
        # @return [JobStatus]
        def self.create(type, value)
          case type
          when :pbs
            PbsJobStatus.transform(value)
          else
            raise ArgumentError, "Unknown job status type: #{type}"
          end => hash

          JobStatus.new(hash)
        end

        def self.not_found(message, job_id = nil)
          { status: STATUS_NOT_FOUND, result: nil, error: message, job_id:, raw: nil }
        end
      end
    end
  end
end
