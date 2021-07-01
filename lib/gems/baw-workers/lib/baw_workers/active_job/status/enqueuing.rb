# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    module Status
      # Handles enqueuing of jobs with statuses
      module Enqueuing
        # hook called by ActiveJob around enqueuing
        # @return [::ActiveJob::Base]
        def around_enqueue_check_and_create_status
          check_job_id(job_id)

          # 4 cases
          old_status = persistance.get(job_id)
          success =
            case old_status
            in nil
              # status does not exist: create
              create
            in StatusData if executions.positive?
              # status does exist, and we're retrying the job: set status
              merge_existing_job(old_status)
            in StatusData if executions.zero?
              # status does exist, and is old: delete, then create
              persistance.remove(job_id) && create
            else
              # status does exist, and is a duplicate: handled by Unique
              raise "Unexpected case: #{old_status},#{executions}"
            end

          raise BawWorkers::ActiveJob::EnqueueError, 'failed to create status' unless success

          begin
            result = yield

            unless result
              logger.error("#{STATUS_MODULE_NAME} removed status after aborted creation", job_id: job_id)
              persistance.remove(job_id)
            end

            result
          rescue StandardError => e
            logger.error("#{STATUS_MODULE_NAME} removed status after error raised during creation", job_id: job_id)
            persistance.remove(job_id)

            raise e
          end
        end

        private

        def delay_ttl
          now = @status&.time || Time.now
          [0, ((scheduled_at || now).to_i - now.to_i)].max
        end

        def _job_name
          # the Identity is optional, so the job may or may not have a name method
          return nil unless respond_to?(:name)

          job_name = name
          return nil if job_name.nil?
          return nil if job_name == job_id

          job_name
        end

        def create
          @status = StatusData.new(
            job_id: job_id,
            name: _job_name,
            status: STATUS_QUEUED,
            messages: [],
            options: serialize.deep_symbolize_keys,
            progress: 0,
            total: 1
          )

          logger.debug do
            { message: "#{STATUS_MODULE_NAME}: Creating status", status: @status }
          end

          persistance.create(@status, delay_ttl: delay_ttl)
        end

        def merge_existing_job(status)
          raise "can't merge a job with 0 executions" if executions.zero?

          # if this job is being tried again, add old messages to the log

          messages = []
          messages << 'Attempt 1' if executions == 1
          messages.push(*(status&.messages || []))
          messages << "Attempt #{executions + 1}"

          # clone old status
          @status = status.new(
            messages: messages,
            status: STATUS_QUEUED,
            options: serialize.deep_symbolize_keys,
            progress: 0,
            total: 1
          )

          logger.debug do
            { message: "#{STATUS_MODULE_NAME}: Updating status for job retry", status: @status,
              executions: executions }
          end

          persistance.set(@status)
        end
      end
    end
  end
end
