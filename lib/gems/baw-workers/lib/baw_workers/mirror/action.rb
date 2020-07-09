# frozen_string_literal: true

module BawWorkers
  module Mirror
    # Copies files from one location to another.
    class Action < BawWorkers::ActionBase
      class << self
        # Get the queue for this action. Used by Resque. Overrides resque-status class method.
        # @return [Symbol] The queue.
        def queue
          Settings.actions.mirror.queue
        end

        # Perform work. Used by Resque.
        # @param [String] source
        # @param [String, Array<String>] destinations
        # @return [Boolean] true if successfully copied
        def action_perform(source, destinations)
          BawWorkers::Config.logger_worker.info(name) do
            "Started mirroring from #{source} to '#{destinations}'."
          end

          begin
            source_file, destination_files = action_validate(source, destinations)
            result = BawWorkers::Config.file_info.copy_to_many(source_file, destination_files)
          rescue StandardError => e
            BawWorkers::Config.logger_worker.error(name) { e }
            BawWorkers::Mail::Mailer.send_worker_error_email(
              BawWorkers::Mirror::Action,
              { source: source, destinations: destinations },
              queue,
              e
            )
            raise e
          end

          BawWorkers::Config.logger_worker.info(name) do
            "Completed mirror with result '#{result}'."
          end

          result
        end

        # Enqueue a file mirror request.
        # @param [String] source
        # @param [String, Array<String>] destinations
        # @return [void]
        def action_enqueue(source, destinations)
          source_file, destination_files = action_validate(source, destinations)
          result = BawWorkers::Mirror::Action.create(source: source_file, destinations: destination_files)
          BawWorkers::Config.logger_worker.info(name) do
            "Job enqueue returned '#{result}' using source #{source_file} and destinations #{destination_files.join(', ')}."
          end
          result
        end

        # Validate that source and destinations are paths, and are compatible with each other.
        def action_validate(source, destinations)
          source_file = BawWorkers::Validation.normalise_file(source)
          dest_files = BawWorkers::Validation.normalise_files(destinations, false).compact

          [source_file, dest_files]
        end

        # Get a Resque::Status hash for if a mirror job has a matching payload.
        # @param [String] source
        # @param [String, Array<String>] destinations
        # @return [Resque::Plugins::Status::Hash] status
        def get_job_status(source, destinations)
          source_file, destination_files = action_validate(source, destinations)
          payload = { source: source_file, destinations: destination_files }
          BawWorkers::ResqueApi.status(BawWorkers::Mirror::Action, payload)
        end
      end

      def perform_options_keys
        ['source', 'destinations']
      end

      # Produces a sensible name for this payload.
      # Should be unique but does not need to be. Has no operational effect.
      # This value is only used when the status is updated by resque:status.
      def name
        "Mirroring: from=#{@options['source']}, to=#{@options['destinations']}"
      end
    end
  end
end
