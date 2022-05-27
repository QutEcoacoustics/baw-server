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

          # 4 cases (+ race conditions)
          old_status = persistance.get(job_id)

          case old_status
          in nil
            # status does not exist: create
            create
          in StatusData if executions.positive?
            # status does exist, and we're retrying the job: set status
            merge_existing_job(old_status)
          in StatusData if executions.zero? && status&.terminal?
            # status does exist, and is old: delete, then create
            raise BawWorkers::ActiveJob::EnqueueError, 'failed to remove old status' unless persistance.remove(job_id)

            create
          else
            # status does exist, and is a duplicate: handled by Unique
            false
            #raise "Unexpected case: #{old_status.inspect},#{executions}"
          end => create_result

          if create_result == false
            # will throw or will continue, in the continue case we do not want to enqueue job, so return false
            handle_bad_create_result
            return false
          end

          begin
            result = yield

            unless result
              logger.error("#{STATUS_TAG} removed after aborted creation", job_id:)
              persistance.remove(job_id)
            end

            result
          rescue StandardError => e
            logger.error("#{STATUS_TAG} removed after error raised during creation", job_id:)
            persistance.remove(job_id)

            raise e
          rescue Async::Stop => e
            # this was added during a debugging session where this was being raised but not handled
            logger.error("#{STATUS_TAG} removed after stop raised during creation", job_id:,
              message: e.message, exception: e)
            persistance.remove(job_id)
            raise e
          end
        end

        private

        def delay_ttl
          now = @status&.time || Time.now
          [0, ((scheduled_at || now).to_i - now.to_i)].max
        end

        def safe_job_name
          # the Identity is optional, so the job may or may not have a name method
          return nil unless respond_to?(:name)

          job_name = name
          return nil if job_name.nil?
          return nil if job_name == job_id

          job_name
        rescue StandardError => e
          "error while generating name: #{e.message}"
        end

        def create(messages = nil)
          @status = StatusData.new(
            job_id:,
            name: safe_job_name,
            status: STATUS_QUEUED,
            messages: messages || [],
            options: serialize.deep_symbolize_keys,
            progress: 0,
            total: 1
          )

          logger.debug do
            { message: "#{STATUS_TAG}: creating", job_id:, name: }
          end

          persistance.create(@status, delay_ttl:)
        end

        def handle_bad_create_result
          # OK: if we're here and ready to throw, one of two cases have happened:
          # 1: genuine bug in the code
          # 2: a race condition has happened where the previous safe guards have completed,
          #    but in the meantime another thread has completed safe guards and has been enqueued.
          # For 2: check if the status that was preventing us from enqueuing is valid, and suppress error.
          duplicate_status = persistance.get(job_id)
          logger.warn("#{STATUS_TAG}: creating failed, duplicate status detected", job_id:)
          if duplicate_status.queued? || duplicate_status.working?
            # probably the same job, has the same id and status
            logger.warn(
              "#{STATUS_TAG}: duplicate status is similar, aborting instead of throwing",
              job_id:,
              status: @status
            )
            # if the unique module is included indicate why we failed
            @unique = false if defined?(@unique)
            @status = duplicate_status
          else
            raise BawWorkers::ActiveJob::EnqueueError, "failed to create status: #{@status.inspect}"
          end
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
            messages:,
            status: STATUS_QUEUED,
            options: serialize.deep_symbolize_keys,
            progress: 0,
            total: 1
          )

          logger.debug do
            {
              message: "#{STATUS_TAG}: updating for job retry",
              status: @status,
              executions:
            }
          end

          result = persistance.set(@status)

          raise BawWorkers::ActiveJob::EnqueueError, 'failed to merge status' unless result

          result
        end
      end
    end
  end
end
