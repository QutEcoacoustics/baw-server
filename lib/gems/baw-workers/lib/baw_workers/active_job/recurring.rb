# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    # Defines how a job should be scheduled.
    # This module must be activated if you want to use regularly scheduled
    # jobs (i.e. not invoked by an action elsewhere in the app).
    # This is a helper used in bin/baw-workers baw:worker:run_scheduler
    # and also acts as a wrapper making resque-scheduler compatible with
    # active job.
    # @example
    #   class MyJob < BawWorkers::Jobs::ApplicationJob
    #     queue_as :default
    #     recurring_at '0 0 * * *' # every day at midnight
    #     def perform(*args)
    #       # do something
    #     end
    #   end
    #
    module Recurring
      # @!parse
      #   extend ClassMethods
      #   extend ActiveSupport::Concern
      #   include ::ActiveJob::Base
      #   include ::ActiveJob::Core
      #   include ::ActiveJob::Logger

      extend ActiveSupport::Concern

      # Class methods for the Recurring module.
      module ClassMethods
        # @!attribute [rw] recurring_cron_schedule
        #   @return [string] The cron schedule for this recurring job.

        # Sets the cron schedule for this job.
        # @param [String] cron_schedule the cron schedule for this job. This is a 6-star schedule.
        # @raise [ArgumentError] if cron_schedule is not a string
        # @return [void]
        def recurring_at(cron_schedule)
          raise ArgumentError, 'cron_schedule must be a string' unless cron_schedule.is_a?(String)

          self.recurring_cron_schedule = cron_schedule
        end

        # override resque-scheduler's default behaviour to adapt it to work with active job.
        # https://github.com/resque/resque-scheduler/tree/121e3427d1211baf8354067321d1f1dd14c7e4a1#support-for-resque-status-and-other-custom-jobs
        # https://github.com/JustinAiken/active_scheduler/blob/master/lib/active_scheduler/resque_wrapper.rb
        def scheduled(_queue, _klass, *args)
          # _queue is ignored because the jobs determine what queue they are on
          # _klass is ignored because we know what class we are
          # we pass along args, but our current wrapper doesn't allow setting any
          perform_later(*args)
        end

        def __setup_recurring
          class_attribute :recurring_cron_schedule, instance_accessor: false
        end
      end

      included do
        __setup_recurring
      end

      prepended do
        __setup_recurring
      end
    end
  end
end
