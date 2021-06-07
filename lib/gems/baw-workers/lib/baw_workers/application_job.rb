# frozen_string_literal: true

module BawWorkers
  class ApplicationJob < ::ActiveJob::Base
    # dealing with exceptions: https://edgeguides.rubyonrails.org/active_job_basics.html#exceptions
    #rescue_from(ActiveRecord::RecordNotFound) do |exception|
    # Do something with the exception
    #end

    # retrying or discarding:
    #retry_on CustomAppException # defaults to 3s wait, 5 attempts

    #discard_on ActiveJob::DeserializationError
  end
end
