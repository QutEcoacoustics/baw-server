# frozen_string_literal: true

module BawWorkers
  module Jobs
    class IntentionalRetry < StandardError; end

    # Base class for application (our) jobs
    class ApplicationJob < ::ActiveJob::Base
      # @!parse
      #   prepend BawWorkers::ActiveJob::Identity
      #   prepend BawWorkers::ActiveJob::Status
      #   include BawWorkers::ActiveJob::Extensions
      #   include BawWorkers::ActiveJob::Arguments
      #   include BawWorkers::ActiveJob::Concurrency
      #   include BawWorkers::ActiveJob::Recurring
      #   extend BawWorkers::ActiveJob::Arguments::ClassMethods
      #   extend BawWorkers::ActiveJob::Extensions::ClassMethods
      #   extend BawWorkers::ActiveJob::Concurrency::ClassMethods
      #   extend BawWorkers::ActiveJob::Recurring::ClassMethods
      #   extend ::ActiveJob::Exceptions::ClassMethods
      #   include ::ActiveJob::QueueName
      #   extend ::ActiveJob::QueueName::ClassMethods

      # !IMPORTANT! includes and extends of this class are done in the initializer
      # so that they can be reloaded and occur in the right order. See
      # config/initializers/active_job.rb

      # dealing with exceptions: https://edgeguides.rubyonrails.org/active_job_basics.html#exceptions
      #rescue_from(ActiveRecord::RecordNotFound) do |exception|
      # Do something with the exception
      #end

      # retrying or discarding:
      #retry_on IntentionalRetry # defaults to 3s wait, 5 attempts

      #discard_on ActiveJob::DeserializationError

      def inherited(_sub_class)
        super
        include SemanticLogger::Loggable
      end

      class << self
        # By convention all of jobs are queued to queues with the current environment suffixed.
        # https://github.com/rails/rails/blob/main/activejob/lib/active_job/queue_name.rb#L48
        # @param [Symbol] name
        # @return [Symbol]
        def queue_name_from_part(name)
          name = super(name)
          name = name.to_s + "_#{BawApp.env}" unless name.end_with?(BawApp.env)
          name
        end
      end

      before_enqueue do
        # check we're enqueuing to a queue we know about
        next if Settings.queue_to_process_includes?(queue_name)

        logger.error("No workers are monitoring the queue `#{queue_name}` - the job may not run")

        next unless BawApp.dev_or_test?

        throw :abort
      end

      discard_on(StandardError, &:notify_error)

      def notify_error(error)
        logger.error('Unhandled job error', error)
        BawWorkers::Mail::Mailer.send_worker_error_email(
          self.class,
          arguments,
          queue_name,
          error
        )
        # raise properly
        raise error
      end
    end
  end
end
