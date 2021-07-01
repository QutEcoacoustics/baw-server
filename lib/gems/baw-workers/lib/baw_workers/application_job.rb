# frozen_string_literal: true

module BawWorkers
  class IntentionalRetry < StandardError; end

  # Base class for application (our) jobs
  class ApplicationJob < ::ActiveJob::Base
    # @!parse
    #   prepend BawWorkers::ActiveJob::Identity
    #   prepend BawWorkers::ActiveJob::Status
    #   include BawWorkers::ActiveJob::Extensions
    #   extend BawWorkers::ActiveJob::Extensions::ClassMethods
    #   include ::ActiveJob::Exceptions::ClassMethods

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
  end
end
