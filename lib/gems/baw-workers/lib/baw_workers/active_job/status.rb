# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    # Provides helper methods for querying the status of a job.
    # Include BawWorkers::ActiveJob::Status in you ActiveJob::Base class.
    #
    #
    # For example
    #
    #       class ApplicationJob < ActiveJob::Base
    #

    #       class ExampleJob
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
      include Identity

      class Killed < RuntimeError; end

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
      end

      included do
        around_enqueue :check_and_create_status
        around_perform :perform_with_status
      end

      attr_reader :job_id
      attr_reader :status

      # hook called by ActiveJob
      # @param job [ActiveJob::Base]
      def check_and_create_status(job, &block)
        # get the job id from the job data
        @job_id ||= self.job_id(job)
        raise TypeError, "Invalid job_id #{@job_id}" unless @job_id.is_a(String)

        @status = StatusData.new(
          job_id: @job_id,
          name: name(job),
          status: STATUS_QUEUED,
          messages: [],
          options: job.serialize,
          progress: 0,
          total: 1
        )
        delay_ttl = [0, (job.scheduled_at - Time.now).to_i].max
        persistance.create(@status, delay_ttl: delay_ttl)
        logger.debug { "BawWorkers::ActiveJob::Status created status with id #{@job_id}" }

        result = yield &block

        if !result
          logger.debug { "BawWorkers::ActiveJob::Status removed status with id #{@job_id} after failed creation" }
          persistance.remove(@job_id)
        end

        result
      end

      # hook called by ActiveJob
      # @param job [ActiveJob::Base]
      def perform_with_status(job, &block)
        @job_id ||= job_id(job)
        logger.debug { "BawWorkers::ActiveJob::Status fetching status with id #{@job_id}" }
        @status = persistance.get(@job_id)
        logger.debug { "BawWorkers::ActiveJob::Status fetched status with id #{@job_id} = #{@status.status}" }


        safe_perform!(job, &block)
      end

      def safe_perform!(job, &block)
        update_status(STATUS_WORKING)

        result = yield &block

        completed("Completed at #{Time.now}")
        on_success if respond_to?(:on_success)

        return result

        rescue Killed
          persistance.killed(@job_id)
          on_killed if respond_to?(:on_killed)
        rescue StandardError => e
          update_status(STATUS_FAILED, "The task failed because of an error: #{e}")
          if respond_to?(:on_failure)
            on_failure(e)
          else
            raise e
          end
      end

      # report progress and check if we should be killed
      # will kill if `should_kill?` is true
      def report_progress(progress, total, *messages)
        raise ArgumentError, "report_progress total was #{total} which is not a number") if total.to_d <= 0.0
        raise ArgumentError, "report_progress progress was #{progress} which is not a number") if progress.to_d <= 0.0

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
        persistance.should_kill?(@job_id)
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
        logger.debug { "BawWorkers::ActiveJob::Status updating status with id #{@job_id} to #{status}" }
        persistance.set(@status)
      end

      private

      # @return [BawWorkers::ActiveJob::Status::Persistance]
      def persistance
        @persistance ||= Persistance.instance
      end

      module Types
        include Dry.Types()
      end
    end
  end
end
