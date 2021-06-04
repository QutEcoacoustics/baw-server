class ApplicationJob < ActiveJob::Base
  # we have  ActiveJob::Plugins::AutoIdentity included in ActiveJob::Base
  # but we want to ensure our jobs are conscious about their identity...
  prepend BawWorkers::ActiveJob::Identity

  # dealing with exceptions: https://edgeguides.rubyonrails.org/active_job_basics.html#exceptions
  #rescue_from(ActiveRecord::RecordNotFound) do |exception|
  # Do something with the exception
  #end

  # retrying or discarding:
  #retry_on CustomAppException # defaults to 3s wait, 5 attempts

  #discard_on ActiveJob::DeserializationError

  # bind to hooks
end
