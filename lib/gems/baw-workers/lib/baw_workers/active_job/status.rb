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
    #         def on_errored
    #           # called if job raises
    #         end
    #
    #         def on_failed
    #           # called if job fails intentionally
    #         end
    #       end
    #
    # This job would iterate num times updating the status as it goes. At the end
    # we update the status telling anyone listening to this job that its complete.
    module Status
      # @!parse
      #   extend ClassMethods
      #   extend ActiveSupport::Concern
      #   include ::ActiveJob::Base
      #   include ::ActiveJob::Core
      #   include ::ActiveJob::Logger
      #   include BawWorkers::ActiveJob::Identity
      #   extend BawWorkers::ActiveJob::Status::Enqueuing

      extend ActiveSupport::Concern
      include BawWorkers::ActiveJob::Status::Enqueuing

      # Represents a kill event for a job that's just been killed
      class Killed < RuntimeError
        attr_accessor :kill_location

        def initialize(message, location)
          @kill_location = location
          super(message)
        end
      end

      STATUS_QUEUED = 'queued'
      STATUS_WORKING = 'working'
      STATUS_COMPLETED = 'completed'
      STATUS_FAILED = 'failed'
      STATUS_KILLED = 'killed'
      STATUS_ERRORED = 'errored'

      STATUSES = ::BawWorkers::Dry::Types::Statuses.values.to_a.freeze
      TERMINAL_STATUSES = [
        STATUS_COMPLETED,
        STATUS_FAILED,
        STATUS_ERRORED,
        STATUS_KILLED
      ].freeze

      # ::nodoc::
      module ClassMethods
        private

        def status_setup
          around_enqueue :around_enqueue_check_and_create_status
          around_perform :around_perform_with_status

          IntrumentationSubscriber.attach_to :active_job

          discard_on BawWorkers::ActiveJob::Status::Killed
        end
      end

      prepended do
        status_setup
      end

      included do
        status_setup
      end

      attr_reader :status

      # Update the #status attribute with a fresh status check from Redis.
      # @return [StatusData]
      def refresh_status!
        logger.measure_debug("#{STATUS_TAG} fetching for #{job_id}") do
          @status = persistance.get(job_id)
        end
      end

      # Marks a job for death (to be killed).
      # The next `tick` or `report_progress` done by the remote job will check
      # for this job's ID in the kill list and will #kill! if necessary.
      def mark_for_kill!
        persistance.mark_for_kill(job_id)
      end

      protected

      # Report progress and check if we should be killed.
      # Will kill if `should_kill?` is true.
      # Should only be called by a worker.
      def report_progress(progress, total, *messages)
        total = parse_decimal(total, 'total')
        progress = parse_decimal(progress, 'progress')

        update_status(*messages, progress: progress, total: total)

        kill! if should_kill?
      end

      # Report a message and check if we should be killed.
      # Will kill if `should_kill?` is true.
      # Should only be called by a worker.
      def tick(*messages)
        update_status(*messages, status: STATUS_WORKING)

        kill! if should_kill?
      end

      # Add a message to the job status.
      # Does not trigger kill!
      # Should only be called by a worker.
      # @return [Boolean] if message was persisted
      def push_message(message)
        update_status(message)
      end

      # Should only be called by a worker.
      def should_kill?
        persistance.should_kill?(job_id)
      end

      # Kills the current job by raising BawWorkers::ActiveJob::Status::Killed
      # Should only be called by a worker.
      # @raise [Killed] will raise Killed to kill the job.
      # @return [void]
      def kill!
        raise Killed.new("Killed at #{Time.now}", caller_locations(1, 1))
      end

      # Marks the current job as failed but does not raise an exception.
      # Halts the job.
      # Should only be called by a worker.
      # @return [void]
      def failed!(*messages)
        update_status(*messages, status: STATUS_FAILED)
        throw :halt
      end

      # Marks the current job as completed.
      # Halts the job.
      # A job's status is updated automatically to complete if no other terminal event occurs - you do not have to call this
      # unless you want to quit early and successfully.
      # Should only be called by a worker.
      # @return [void]
      def completed!(*messages)
        update_status(*messages, status: STATUS_COMPLETED)
        throw :halt
      end

      # Callback invoke when a job is completed. Implement in your job class.
      # By default does nothing.
      def on_completed
        # noop
      end

      # Callback invoke when a job raises an error. Implement in your job class.
      # By default does nothing.
      # @param error [StandardError]
      # @return [Boolean] return true to suppress raising the exception
      def on_errored(_error)
        false
      end

      # Callback invoke when a job marks itself as failed. Implement in your job class.
      # By default does nothing.
      def on_failure
        # noop
      end

      # Callback invoke when a job is killed. Implement in your job class.
      # By default does nothing.
      def on_killed
        # noop
      end

      private

      STATUS_TAG = '[Status]'

      # hook called by ActiveJob
      def around_perform_with_status(&block)
        ensure_status

        safe_perform!(&block)
      end

      def safe_perform!(&block)
        update_status(status: STATUS_WORKING)

        kill! if should_kill?

        result = catch(:halt) {
          block.call
               .tap { update_status("Completed at #{Time.now}", status: STATUS_COMPLETED) }
        }

        on_failure if @status.failed?
        on_completed if @status.completed?

        result
      rescue Killed => e
        handle_kill(e)
      rescue StandardError => e
        raise e unless handle_error(e)
      end

      # @param [Killed] kill_error
      def handle_kill(kill_error)
        logger.warn("#{STATUS_TAG} job killed", location: kill_error.kill_location)
        persistance.killed(job_id)
        on_killed
      ensure
        update_status(kill_error.message, status: STATUS_KILLED)
      end

      def handle_error(error)
        logger.warn("#{STATUS_TAG} job failed", error: error.to_s)
        update_status(
          "The job failed because of an error: #{error} at #{error&.backtrace&.slice(5)}",
          status: STATUS_ERRORED
        )

        handle = on_errored(error)

        !!handle
      end

      def check_job_id(job_id)
        raise TypeError, "Invalid job_id #{job_id}" unless job_id.is_a?(String)
        raise ArgumentError, 'job_id cannot contain a space' if job_id.include?(' ')

        job_id
      end

      # when the job is performed immediately then status may not exist
      def ensure_status
        return unless @status.nil?

        refresh_status!
        return unless @status.nil?

        logger.debug("#{STATUS_TAG} created during perform")
        create([
          'previous status not found - was this job run with #perform_now'
        ])
      end

      #
      # Update this jobs status by sending the status to Redis. Also updates the instance variable @status.
      # All parameters are optional and default to their current respective state if omitted.
      #
      # @param [Array<String>] *messages One or messages to add to the status
      # @param [String] status The new status
      # @param [BigDecimal] progress The new progress
      # @param [BigDecimal] total The new total for progress
      # @return [Boolean] True if status was updated successfully
      def update_status(*messages, status: nil, progress: nil, total: nil)
        ensure_status

        status ||= @status.status
        unless TERMINAL_STATUSES.include?(status) || status == STATUS_WORKING
          raise ArgumentError,
            "status #{status} is not valid at this stage"
        end

        # copy attributes to a new @status object (structs are readonly)
        old_status = @status.status
        @status = @status.new(
          status: status,
          messages: @status.messages + (messages || []),
          progress: progress || @status.progress,
          total: total || @status.total
        )
        logger.debug do
          {
            message: "#{STATUS_TAG} updating",
            old_status: old_status,
            status: status,
            percent_complete: @status.percent_complete,
            messages: messages
          }
        end
        persistance.set(@status).tap do |successful|
          next if successful

          logger.error { 'Failed to update status ' }
        end
      end

      def parse_decimal(input, name)
        BigDecimal(input)
      rescue ArgumentError => e
        raise ArgumentError,
          "#{name} was `#{input}` which is not a valid number: #{e.message}.\n#{e.backtrace.slice(5)}\n<snip>"
      end

      # @return [Module<BawWorkers::ActiveJob::Status::Persistance>]
      def persistance
        @persistance ||= BawWorkers::ActiveJob::Status::Persistance
      end

      # https://github.com/rails/rails/blob/30033e6a1d25dcd80ec235af820ba3f780e9e2ff/activesupport/lib/active_support/rescuable.rb#L164
      # dirty monkey patch
      # discard_on is one-shot (multiple classes can't hook into it)
      # after_perform won't run?
      # around_perform is not reliable because order dictates we may miss some failures
      class IntrumentationSubscriber < ActiveSupport::Subscriber
        def discard(event)
          job = event.payload[:job]
          error = event.payload[:error]
          job.send(:update_status, "The job was discarded: #{error} is registered by discard_on", status: STATUS_FAILED)
        rescue StandardError => e
          Rails.logger.error('failed to set status', e)
        end
      end
    end
  end
end
