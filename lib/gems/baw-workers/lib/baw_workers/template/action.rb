# frozen_string_literal: true

module BawWorkers
  module Template
    # demonstrates how to create a minimal worker that adheres to our required behaviors
    class Action < BawWorkers::ActionBase
      NAME = 'template'

      # These methods do not require a class instance.
      class << self
        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        def queue
          settings = Settings.actions[:template]
          settings.nil? ? "#{NAME}_default" : settings.queue
        end

        # Perform work! Callstack: Resque->ActionBase::perform->Action::action_perform.
        # @param [Hash] params
        # @return [Hash] result information
        def action_perform(params)
          BawWorkers::Config.logger_worker.info(logger_name) {
            "Started #{NAME} action using '#{params}'."
          }

          # DO WORK!
        end

        # Enqueue a payload.
        # @param [Hash] template_params - the payload
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def self.action_enqueue(template_params)
          # call the resque-status create method
          result = BawWorkers::Template::Action.create(template_params: template_params)

          BawWorkers::Config.logger_worker.info(logger_name) do
            "Job enqueue returned '#{result}' using #{template_params}."
          end

          result
        end
      end

      # Produces a sensible name for this payload.
      # Should be unique but does not need to be. Has no operational effect.
      # This value is only used when the status is updated by resque:status.
      def name
        "#{NAME}:#{@uuid}"
      end
    end
  end
end
