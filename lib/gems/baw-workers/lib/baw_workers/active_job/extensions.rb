# frozen_string_literal: true

require 'dry/monads'

module BawWorkers
  module ActiveJob
    # patch until rails 7
    class EnqueueError < StandardError; end

    # A module for ActiveJob that implements some helper methods
    module Extensions
      extend ActiveSupport::Concern
      # @!parse
      #   extend ActiveSupport::Concern
      #   include ::ActiveJob::Base
      #   include ::ActiveJob::Core
      #   include ::ActiveJob::Logger
      #   include ::ActiveJob::Enqueuing

      # Class method extensions for ActiveJob
      module ClassMethods
        include ::Dry::Monads[:result]

        # TODO: when Rails 7 is released, these methods may be able to change
        #   to be simpler wrappers because perform_later now accepts a block
        #   that is always invoked.
        #   See: https://github.com/rails/rails/blob/main/activejob/lib/active_job/enqueuing.rb

        # (see #perform_later)
        # The same as #perform_later except will raise if job was not successfully enqueued.
        # It also supports a block callback on failure to enqueue - which is missing in
        # #perform_later until Rails 7.
        # @raise [StandardError] when the job fails to enqueue
        # @return [void]
        def perform_later!(...)
          job = job_or_instantiate(...)

          result = job.enqueue

          yield job if block_given?

          raise EnqueueError, "job with id #{job.job_id} failed to enqueue" if result == false

          result
        end

        def perform_later(...)
          logger.warn 'Perform later is tricky to use; it has a variant return type and will not surface errors as we expect'
          raise 'perform_later does not support blocks' if ::Rails::VERSION::MAJOR < 7 && block_given?

          super(...)
        end

        # (see #perform_later)
        # The same as #perform_later except always returns the job wrapped in
        # a ::Dry::Monad::Result.
        # @return [::Dry::Monad::Result<::ActiveJob::Core>]
        def try_perform_later(...)
          job = job_or_instantiate(...)

          result = job.enqueue

          yield job if block_given?

          return Failure(job) if result == false

          Success(job)
        end
      end

      # best not to monkey patch unless needed
      # def halted_callback_hook(filter, name)
      #   logger.debug do
      #     { message: 'ActiveJob callbacks halted', filter: filter, name: name }
      #   end
      #   super
      # end
    end
  end
end

raise 'Fix the rails patches in BawWorkers::ActiveJob::Extensions' if ::Rails::VERSION::MAJOR >= 7
