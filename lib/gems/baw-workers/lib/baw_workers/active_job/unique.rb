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
      include Status

      # @!parse
      #   extend ClassMethods
      #   extend ActiveSupport::Concern
      #   include ActiveJob::Base
      #   include ActiveJob::Core
      #   include ActiveJob::Logger

      # ::nodoc::
      module ClassMethods
        private

        def unique_setup
          # active job hook:
          before_enqueue :enqueue_check_uniqueness, prepend: true
        end
      end

      prepended { unique_setup }

      included { unique_setup }

      # Was this job unique when enqueued?
      # @return [Boolean,nil] nil if uniqueness has not yet been evaluated
      def unique?
        @unique
      end

      private

      # param job [ActiveJob::Base]
      def enqueue_check_uniqueness
        check_job_id(job_id)
        abort unless id_unique?(job_id)
        @unique = true
      end

      attr_writer :unique

      #
      # Aborts the current enqueue chain
      #
      # @return [void]
      #
      def abort
        logger.debug { { message: 'BawWorkers::ActiveJob::Unique job already exists, aborting', job_id: job_id } }
        @unique = false
        throw :abort
      end

      def id_unique?(id_to_test)
        return true unless persistance.exists?(id_to_test)

        @status = persistance.get(id_to_test)

        # race conditions could mean we fail to get status after existence test
        if @status.nil? || @status.terminal?
          logger.debug do
            { message: 'BawWorkers::ActiveJob::Unique existing job is terminal, ignoring presence and continuing with new job',
              job_id: id_to_test }
          end
          return true
        end

        false
      end

      # @return [Module<BawWorkers::ActiveJob::Status::Persistance>]
      def persistance
        @persistance ||= BawWorkers::ActiveJob::Status::Persistance
      end
    end
  end
end
