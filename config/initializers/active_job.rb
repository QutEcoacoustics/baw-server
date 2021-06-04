# Use a real queuing backend for Active Job (and separate queues per environment)
Rails.application.config.active_job.queue_adapter = :resque

Rails.application.config.active_job.default_queue_name = Settings.actions.active_job_default.queue
Rails.application.config.active_job.queue_name_prefix = ''

# Include the resque plugins we want in standard ActiveJobs classes.
# This works well for jobs defined by third parties (like Rails!).
ActiveSupport.on_load(:active_job) do
  # this extension point affects all jobs, including framework and library jobs!
  # See also ApplicationJob for an extension point for only our jobs
  ActiveJob::Base.class_eval do
    include BawWorkers::ActiveJob::AutoIdentity
    include BawWorkers::ActiveJob::Status
    include BawWorkers::ActiveJob::Unique
  end

  ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper.class_eval do
    extend Resque::Plugins::JobStats
  end
end
