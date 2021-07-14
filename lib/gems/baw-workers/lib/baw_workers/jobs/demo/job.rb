# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Demo
      # a class showing the minimal setup needed for creating a baw job
      class Job < ApplicationJob
        queue_as :default
        perform_expects Demo::Payload

        def name
          "name #{arguments[0].parameter}"
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_uuid(self, 'demo_job')
        end

        # @param payload [BawWorkers::Jobs::Demo::Payload]
        def perform(payload)
          logger.debug do
            'test message'
          end
          completed!(payload.parameter)
        end
      end
    end
  end
end
