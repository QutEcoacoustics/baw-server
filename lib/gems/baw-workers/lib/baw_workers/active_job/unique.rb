# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    class UniqueError < StandardError; end

    module Unique
      extend ActiveSupport::Concern
      include Identity
      include Status

      included do
        # active job hook:
        before_enqueue(:prepend) :enqueue_check_uniqueness
      end

      class_methods do
      end


      # param job [ActiveJob::Base]
      def enqueue_check_uniqueness(job)
          # get job_id
          @job_id ||= job_id(job)

          raise :abort unless should_run?(job_id)
      end

      private

      def should_run?(job_id)
        return true unless persistance.exists?(job_id)

        @status = persistance.get(job_id)

        if @status.terminal?
          logger.debug { "BawWorkers::ActiveJob::Unique job with id #{@job_id} is terminal, removing in favour of new job" }
          persistance.remove(job_id)
          return true
        end

        logger.debug { "BawWorkers::ActiveJob::Unique job with id #{@job_id} already exists, aborting" }
        false
      end

      # @return [BawWorkers::ActiveJob::Status::Persistance]
      def persistance
        @persistance ||= BawWorkers::ActiveJob::Status::Persistance.instance
      end
    end
  end
end
