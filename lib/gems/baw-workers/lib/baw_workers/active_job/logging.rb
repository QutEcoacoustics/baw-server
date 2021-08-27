# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    # Adds logging for active job instrumentation hooks which are currently
    # missed by our logger (rails_semantic_logger).
    module Logging
      def self.setup
        BawWorkers::ActiveJob::Logging::LogSubscriber.attach_to :active_job
      end

      class LogSubscriber < ActiveSupport::LogSubscriber
        # https://github.com/rails/rails/blob/2ab3751781e34ca4a8d477ba53ff307ae9884b0d/activejob/lib/active_job/logging.rb#L91-L121
        def enqueue_retry(event)
          job = event.payload[:job]
          ex = event.payload[:error]
          wait = event.payload[:wait]

          info do
            if ex
              "Retrying #{job.class} in #{wait.to_i} seconds, due to a #{ex.class}."
            else
              "Retrying #{job.class} in #{wait.to_i} seconds."
            end
          end
        end

        def retry_stopped(event)
          job = event.payload[:job]
          ex = event.payload[:error]

          error do
            "Stopped retrying #{job.class} due to a #{ex.class}, which reoccurred on #{job.executions} attempts."
          end
        end

        def discard(event)
          job = event.payload[:job]
          ex = event.payload[:error]

          error do
            { message: "Discarded #{job.class} due to a #{ex.class}.", exception: ex }
          end
        end
      end
    end
  end
end
