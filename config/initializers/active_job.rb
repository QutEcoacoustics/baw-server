# Use a real queuing backend for Active Job (and separate queues per environment)
Rails.application.config.active_job.queue_adapter = :resque

Rails.application.config.active_job.default_queue_name = Settings.actions.active_job_default.queue
Rails.application.config.active_job.queue_name_prefix = ''

# Include the resque plugins we want in standard ActiveJobs classes.
# This works well for jobs defined by third parties (like Rails!).
ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper.class_eval do
  # These plugins are also used in BawWorkers::ActionBase for our own jobs
  extend Resque::Plugins::JobStats
  prepend Resque::Plugins::Status
end
