# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    # Provides helper methods for querying the status of a job.
    # Include BawWorkers::ActiveJob::Status in you ActiveJob::Base class.
    #
    #
    # For example
    #
    #       class ExampleJob < ApplicationJob
    #         include BawWorkers::ActiveJob::Status
    #
    #         def perform(arguments)
    #           i = 0
    #           while i < 100
    #             i += 1
    #             report_progress(i, num)
    #           end
    #           completed("Finished!")
    #         end
    #
    #         def on_killed
    #           # called if job killed
    #         end
    #
    #         def on_completed
    #           # called if job completed
    #         end
    #
    #         def on_failed
    #           # called if job raises
    #         end
    #       end
    #
    # This job would iterate num times updating the status as it goes. At the end
    # we update the status telling anyone listening to this job that its complete.
    module Status
      extend ActiveSupport::Concern
      prepend Identity

      class Killed < RuntimeError; end

      module Types
        include ::Dry.Types()
      end

      STATUS_QUEUED = 'queued'
      STATUS_WORKING = 'working'
      STATUS_COMPLETED = 'completed'
      STATUS_FAILED = 'failed'
      STATUS_KILLED = 'killed'
      STATUSES = Types::String.enum(
        STATUS_QUEUED,
        STATUS_WORKING,
        STATUS_COMPLETED,
        STATUS_FAILED,
        STATUS_KILLED
      )
      EXPIRE_STATUSES = [
        STATUS_COMPLETED,
        STATUS_FAILED,
        STATUS_KILLED
      ].freeze

      class_methods do
        def setup
          around_enqueue :check_and_create_status
          around_perform :perform_with_status

          discard_on BawWorkers::ActiveJob::Status::Killed

          return if ancestors.include?(BawWorkers::ActiveJob::Identity)

          raise TypeError,
                'BawWorkers::ActiveJob::Unique depends on BawWorkers::ActiveJob::Identity but it was not in the ancestors list'
        end
      end

      prepended(&:setup)

      included(&:setup)

      attr_reader :status

      # hook called by ActiveJob
      # @param job [ActiveJob::Base]
      def check_and_create_status(job)
        # get the job id from the job data
        id = job.job_id
        raise TypeError, "Invalid job_id #{id}" unless id.is_a(String)

        # if this job is being tried again, add old messages to the log
        messages = []
        if job.executions.positive?
          messages.push("Attempt #{job.executions - 1}")
          messages.push(*persistance.get(id)&.messages)
        end

        @status = StatusData.new(
          job_id: id,
          name: job.name,
          status: STATUS_QUEUED,
          messages: messages,
          options: job.serialize,
          progress: 0,
          total: 1
        )

        delay_ttl = [0, (job.scheduled_at - Time.now).to_i].max
        persistance.create(@status, delay_ttl: delay_ttl)
        logger.debug { "BawWorkers::ActiveJob::Status created status with id #{id}" }

        result = yield

        unless result
          logger.debug { "BawWorkers::ActiveJob::Status removed status with id #{id} after failed creation" }
          persistance.remove(job_id)
        end

        result
      end

      # hook called by ActiveJob
      # @param job [ActiveJob::Base]
      def perform_with_status(job, &block)
        id = job.job_id
        logger.debug { "BawWorkers::ActiveJob::Status fetching status with id #{id}" }
        @status = persistance.get(id)
        logger.debug { "BawWorkers::ActiveJob::Status fetched status with id #{id} = #{@status.status}" }

        safe_perform!(job, &block)
      end

      def safe_perform!(job)
        update_status(STATUS_WORKING)

        result = yield

        completed("Completed at #{Time.now}")
        on_success if respond_to?(:on_success)

        result
      rescue Killed
        logger.warn { "BawWorkers::ActiveJob::Status job killed with id #{job.job_id}" }
        persistance.killed(job.job_id)
        on_killed if respond_to?(:on_killed)
      rescue StandardError => e
        logger.warn { "BawWorkers::ActiveJob::Status job failed with id #{job.job_id} and error #{e}" }
        update_status(STATUS_FAILED, "The task failed because of an error: #{e}")

        raise e unless respond_to?(:on_failure)

        on_failure(e)
      end

      # report progress and check if we should be killed
      # will kill if `should_kill?` is true
      def report_progress(progress, total, *messages)
        raise ArgumentError, "report_progress total was #{total} which is not a number" if total.to_d <= 0.0
        raise ArgumentError, "report_progress progress was #{progress} which is not a number" if progress.to_d <= 0.0

        @status.progress = progress
        @status.total = total
        tick(*messages)
      end

      # report a message and check if we should be killed
      # will kill if `should_kill?` is true
      def tick(*messages)
        kill! if should_kill?
        update_status(STATUS_WORKING, *messages)
      end

      def should_kill?
        persistance.should_kill?(job_id)
      end

      # kills the current job by raising BawWorkers::ActiveJob::Status::Killed
      def kill!
        update_status(STATUS_KILLED, "Killed at #{Time.now}")
        raise Killed
      end

      def completed(*messages)
        update_status(STATUS_COMPLETED, messages)
      end

      # @param status [String] a valid status
      # @param *messages [Array] one or messages to add to the status
      def update_status(status, *messages)
        raise ArgumentError unless EXPIRE_STATUSES.include?(status) || status == STATUS_WORKING

        @status.status = status
        @status.messages.push(messages)
        logger.debug { "BawWorkers::ActiveJob::Status updating status with id #{job_id} to #{status}" }
        persistance.set(@status)
      end

      private

      # @return [BawWorkers::ActiveJob::Status::Persistance]
      def persistance
        @persistance ||= Persistance.instance
      end
    end
  end
end
