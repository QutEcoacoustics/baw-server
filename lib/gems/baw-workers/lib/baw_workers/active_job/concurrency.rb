# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    # Limits a job class to a certain number of concurrently running instances.
    # @example
    #       class ExampleJob < ApplicationJob
    #         include BawWorkers::ActiveJob::Concurrency
    #
    #         limit_concurrency_to 1, on_limit: :discard
    #         # or
    #         #limit_concurrency_to 1, on_limit: :retry
    #
    #         def perform(arguments)
    #           i = 0
    #           while i < 100
    #             i += 1
    #             report_progress(i, num)
    #           end
    #           completed("Finished!")
    #         end
    #       end
    #
    # This job will only allow one instance to run at a time. If a second instance is
    # started, it will be discarded or retried depending on the value of `on_limit`.
    # The concurrency limit is enforced by a semaphore (a counter) stored in
    # Redis, though this semaphore is not
    # guaranteed to be free from race conditions: concurrency limits can technically
    # be exceeded.
    module Concurrency
      # @!parse
      #   extend ClassMethods
      #   extend ActiveSupport::Concern
      #   include ::ActiveJob::Base
      #   include ::ActiveJob::Core
      #   include ::ActiveJob::Logger

      extend ActiveSupport::Concern

      class ConcurrencyLimitDiscardError < StandardError; end
      class ConcurrencyLimitRetryError < StandardError; end

      # @!attribute [r] concurrency_limit
      #   the maximum number of concurrent instances of this job class
      #   @return [Integer]

      # @!attribute [r] concurrency_action
      #   the action to take when the concurrency limit is reached
      #   @return [Symbol, nil]

      # @!attribute [r] concurrency_parameters
      #   a proc that returns a string coercible object that is used to
      #   create multiple parameterized semaphores
      #   @return [Proc,nil]

      # Class methods for the Concurrency module.
      module ClassMethods
        # @!attribute [rw] concurrency_limit
        #   the maximum number of concurrent instances of this job class
        #   @return [Integer]

        # @!attribute [rw] concurrency_action
        #   the action to take when the concurrency limit is reached
        #   @return [Symbol, nil]

        # @!attribute [rw] concurrency_parameters
        #   a proc that returns a string coercible object that is used to
        #   create multiple parameterized semaphores
        #   @return [Proc,nil]

        # Limits the number of concurrently running instances of this job class.
        # The concurrency limit is enforced by a semaphore (a counter) stored
        # in Redis. The semaphore is checked and incremented when the job is
        # dequeued and is decremented when the job is completed.
        #
        # Normally the concurrency limit is per class, but if a block is given
        # then the concurrency limit is keyed as a tuple of the job class and
        # the block's return value. This allows for multiple concurrency limits
        # per job class. It is recommended that the block return a short string
        # with low cardinality.
        #
        # The concurrency limit is different from the unique job module; the
        # unique job module prevents multiple instances of the same job from being
        # enqueued, while the concurrency module prevents multiple instances of the
        # same job from running at the same time.
        #
        # @param [Integer] limit the maximum number of concurrent instances
        # @param [Symbol] on_limit the action to take when the concurrency limit
        #   is reached. Either `:discard` or `:retry`.
        # @yield [job] a block that is executed when the job is dequeued
        # @yieldparam job [BawWorkers::Jobs::ApplicationJob] the job instance
        # @yieldreturn [String] a string coercible object that is used to create multiple parameterized semaphores
        # @raise [ArgumentError] if limit is not a positive integer or on_limit is not `:discard` or `:retry`
        # @return [void]
        def limit_concurrency_to(limit, on_limit: :discard, &parameters)
          raise ArgumentError, 'limit must be a positive integer' unless limit.is_a?(Integer) && limit.positive?
          raise ArgumentError, 'on_limit must be :discard or :retry' unless [:discard, :retry].include?(on_limit)

          self.concurrency_limit = limit
          self.concurrency_action = on_limit
          self.concurrency_parameters = parameters
        end

        def __setup_concurrency
          around_perform :around_perform_check_concurrency

          retry_on ConcurrencyLimitRetryError
          discard_on ConcurrencyLimitDiscardError

          class_attribute :concurrency_limit, instance_accessor: true
          class_attribute :concurrency_action, instance_accessor: true
          class_attribute :concurrency_parameters, instance_accessor: true
        end
      end

      prepended do
        __setup_concurrency
      end

      included do
        __setup_concurrency
      end

      # ::nodoc::
      # hook called by ActiveJob
      def around_perform_check_concurrency
        # do nothing unless this module is enabled
        return yield if concurrency_limit.nil?

        # get concurrency parameters
        parameter = concurrency_parameters&.call(self)

        # increment and check current instance count
        count = Persistance.increment(self.class.name, parameter)

        # if greater than limit (if set) then perform throttle action
        if count > concurrency_limit
          key = self.class.name + (parameter ? ":#{parameter}" : '')
          message = "Concurrency limit of #{concurrency_limit} reached for #{key}"
          # either discard job or retry later
          if concurrency_action == :discard
            logger.warn("Discarding job. #{message}")
            raise ConcurrencyLimitDiscardError, message
          elsif concurrency_action == :retry
            logger.warn("Retrying job. #{message}")
            raise ConcurrencyLimitRetryError, message
          else
            raise ArgumentError, "Unknown concurrency_action #{concurrency_action}"
          end
        end

        # set expiry for concurrency counter
        # we do this after the increment so that if the job fails to run because the counter is greater than the limit
        # then the counter will expire and the job can be run again.
        Persistance.set_expire(self.class.name, parameter)

        # perform
        yield
      ensure
        # and finally unlock job
        Persistance.decrement(self.class.name, parameter)
      end

      # Singleton persistence module for tracking concurrency.
      module Persistance
        # number of seconds for which to keep track of concurrency
        # this is to prevent a job class from being locked forever in case of a race condition
        # Note: incr and decr don't modify the ttl
        # 30 minutes
        EXPIRE_IN = 1800

        module_function

        # @return [::Redis::Client] the redis client to use
        def redis
          raise 'redis is nil, Persistance singleton must be configured before use' if @redis.nil?

          @redis
        end

        # Configure the persistance module. This module is a singleton.
        # @param redis [::Redis]  The redis client to use
        # @return [Module<Persistance>] the configured Persistance Module
        def configure(redis)
          unless redis.class.ancestors.include?(::Redis)
            raise ArgumentError,
              "redis was not of type Redis, ancestors: #{redis.class.ancestors}"
          end

          @redis = redis
          self
        end

        # Increment the count for a job class.
        # @param class_name [String] the name of the job class.
        # @param parameter [String,nil] the parameter to use for parameterized semaphores.
        # @return [Integer] the new count.
        def increment(class_name, parameter)
          key = key_prefix(class_name, parameter)
          redis.incr(key)
        end

        # Set the expiry for a concurrency counter for a job class.
        # @param class_name [String] the name of the job class.
        # @param parameter [String,nil] the parameter to use for parameterized semaphores.
        # @return [Boolean] true if the expiry was set, false otherwise.
        def set_expire(class_name, parameter)
          key = key_prefix(class_name, parameter)
          redis.expire(key, EXPIRE_IN)
        end

        # Decrement the count for a job class.
        # @param class_name [String] the name of the job class.
        # @param parameter [String,nil] the parameter to use for parameterized semaphores.
        # @return [Integer] the new count.
        def decrement(class_name, parameter)
          key = key_prefix(class_name, parameter)
          new_value = redis.decr(key)

          redis.set(key, 0) if new_value.negative?

          new_value
        end

        # Get the current value of the semaphore for a job class.
        # @param class_name [String] the name of the job class.
        # @param parameter [String,nil] the parameter to use for parameterized semaphores.
        # @return [Integer] the current count.
        def current_count(class_name, parameter)
          key = key_prefix(class_name, parameter)
          redis.get(key).to_i
        end

        def key_prefix(class_name, parameter)
          parameter = parameter.blank? ? '' : ":#{parameter}"
          "active_job:concurrency:#{class_name}#{parameter}:count"
        end
      end
    end
  end
end
