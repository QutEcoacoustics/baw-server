# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Export
      # Generates an export's file in the background.
      class ExportJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.export.queue

        perform_expects ::Export

        # @param export [::Export]
        def self.enqueue(export)
          perform_later!(export)
        end

        def perform(export)
          # A retry runs with executions > 1, so resume: true. So it's safe
          # to re-run an export left in working by the previous attempt.
          export.generate(resume: executions > 1)
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(self, { id: arguments.first&.id })
        end

        def name
          job_id
        end
      end
    end
  end
end
