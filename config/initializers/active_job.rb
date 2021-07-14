# frozen_string_literal: true

# Use a real queuing backend for Active Job (and separate queues per environment)
Rails.application.config.active_job.queue_adapter = :resque

Rails.application.config.active_job.default_queue_name = Settings.actions.active_job_default.queue
Rails.application.config.active_job.queue_name_prefix = ''

# Include the resque plugins we want in standard ActiveJobs classes.
# This works well for jobs defined by third parties (like Rails!).
ActiveSupport.on_load(:active_job) do
  # https://github.com/rails/rails/issues/37270
  Rails.application.config.active_job.queue_adapter = :resque
  ::ActiveJob::Base.queue_adapter = :resque

  # this extension point affects all jobs, including framework and library jobs!
  # See also ApplicationJob for an extension point for only our jobs
  Kernel.const_set(:ACTIVE_JOB_BASE_BACKUP, ::ActiveJob::Base.clone)
  ::ActiveJob::Base.class_eval do
    prepend BawWorkers::ActiveJob::Identity
    prepend BawWorkers::ActiveJob::Status
  end

  BawWorkers::Jobs::ApplicationJob.include(BawWorkers::ActiveJob::Unique)
  BawWorkers::Jobs::ApplicationJob.include(BawWorkers::ActiveJob::Extensions)
  BawWorkers::Jobs::ApplicationJob.include(BawWorkers::ActiveJob::Arguments)

  ::ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper.class_eval do
    extend Resque::Plugins::JobStats
  end

  # our tests run real jobs
  require "#{BawApp.root}/spec/fixtures/jobs" if BawApp.test?
end
