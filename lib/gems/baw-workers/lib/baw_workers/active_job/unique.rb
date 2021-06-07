# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    class UniqueError < StandardError; end

    # Ensure a job is unique before enqueueing it.
    # Relies on BawWorkers::ActiveJob::Status and BawWorkers::ActiveJob::Identity
    # Example
    #       class ExampleJob < ApplicationJob
    #         include BawWorkers::ActiveJob::Identity
    #
    #         def name
    #           "example: #{arguments[0]}"
    #         end
    #
    #         def job_identifier
    #           arguments[0].to_s
    #         end
    #
    #         def perform(arguments)
    #           ...
    #         end
    #       end
    #
    #       ExampleJob.perform_later(123) # will work
    #       ExampleJob.perform_later(123) # will return false
    #       ExampleJob.perform_later(123) do |job| # => false return false
    #         puts job.job_id # get the job id of the job already duplicated
    #         puts successfully_enqueued? # => false
    #         puts unique? # => false
    #       end
    module Unique
      extend ActiveSupport::Concern
      prepend Identity
      include Status

      prepended(&:setup)

      included(&:setup)

      def unique?
        @unique
      end

      # param job [ActiveJob::Base]
      def enqueue_check_uniqueness(job)
        abort unless should_run?(job.job_id)
        @unique = true
      end

      private

      attr_writer :unique

      def setup
        # active job hook:
        before_enqueue :enqueue_check_uniqueness, prepend: true

        return if ancestors.include?(BawWorkers::ActiveJob::Identity)

        raise TypeError,
              'BawWorkers::ActiveJob::Unique depends on BawWorkers::ActiveJob::Identity but it was not in the ancestors list'
      end

      def abort
        logger.debug { "BawWorkers::ActiveJob::Unique job with id #{job_id} already exists, aborting" }
        @unique = false
        raise :abort
      end

      def should_run?(id_to_test)
        return true unless persistance.exists?(id_to_test)

        @status = persistance.get(id_to_test)

        if @status.terminal?
          logger.debug do
            "BawWorkers::ActiveJob::Unique job with id #{id_to_test} is terminal, removing in favour of new job"
          end
          persistance.remove(id_to_test)
          return true
        end

        false
      end

      # @return [BawWorkers::ActiveJob::Status::Persistance]
      def persistance
        @persistance ||= BawWorkers::ActiveJob::Status::Persistance.instance
      end
    end
  end
end
