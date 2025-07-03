# frozen_string_literal: true

module BawWorkers
  module BatchAnalysis
    module Models
      # A specialization of our abstract and generic job status class for PBS.
      module PbsJobStatus
        # @param value [::Dry::Monads::Result<::PBS::Models::Job>]
        def self.transform(value)
          if value.failure?
            case value.failure
            in ::PBS::Errors::JobNotFoundError => e
              return JobStatus.not_found(e.message, e.job_id)
            in StandardError => e
              raise e
            else
              raise StandardError, "Cannot parse PBS Job status: #{value.failure}"
            end
          end

          job = value.value!

          # Often we'll get the job list wrapper, unwrap it.
          # Assuming we only have one job per request.
          # @type [::PBS::Models::Job]
          job = job.jobs.values.first if job.is_a?(::PBS::Models::JobList)

          if job.finished?
            JobStatus::STATUS_FINISHED
          elsif job.begun? || job.running? || job.exiting?
            JobStatus::STATUS_RUNNING
          else
            JobStatus::STATUS_QUEUED
          end => status

          result = ::PBS::Connection.map_exit_status_to_state(job.exit_status)
          error = ::PBS::Connection.map_exit_status_to_reason(job.exit_status)

          {
            status:,
            result:,
            raw: job,
            job_id: job.job_id,
            error:,
            used_walltime_seconds: job&.resources_used&.walltime&.to_i,
            used_memory_bytes: job&.resources_used&.mem&.to_i
          }
        end
      end
    end
  end
end
