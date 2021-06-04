# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Demo
      class Job < ApplicationJob
        queue_as :demo

        def name(job)
          puts "name #{job}"
        end

        def job_id(_job)
          nil
        end

        # @param payload [BawWorkers::Jobs::Demo::Payload]
        def perform(_payload)
          puts 'i did some work'
        end
      end
    end
  end
end
