module BawWorkers
  module Harvest
    # Harvests audio files to be accessible via baw-server.
    class Action

      # Ensure that there is only one job with the same payload per queue.
      include Resque::Plugins::UniqueJob

      # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
      extend Resque::Plugins::JobStats

      # track specific job instances and their status
      include Resque::Plugins::Status

      # include common methods
      include BawWorkers::ActionCommon

      # All methods do not require a class instance.
      class << self

        # Delay when the unique job key is deleted (i.e. when enqueued? becomes false).
        # @return [Fixnum]
        def lock_after_execution_period
          30
        end

        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        def queue
          BawWorkers::Settings.actions.harvest.queue
        end


        # Perform work. Used by Resque.
        # @param [Hash] harvest_params
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_perform(harvest_params)
          begin
            # TODO
            result = true
          rescue Exception => e
            BawWorkers::Config.logger_worker.error(self.name) { e }
            raise e
          end
          result
        end

        # Enqueue a single file for harvesting.
        # @param [Hash] harvest_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue(harvest_params)

          result = BawWorkers::Harvest::Action.create(harvest_params: harvest_params)
          BawWorkers::Config.logger_worker.info(self.name) {
            "Job enqueue returned '#{result}' using #{harvest_params}."
          }
          result
        end

        def action_gather_files
          # top level directory to harvest
          config_file_name = BawWorkers::Settings.actions.harvest.config_file_name
          valid_audio_formats = BawWorkers::Settings.available_formats.audio

          gather_files = BawWorkers::Harvest::GatherFiles.new(
              BawWorkers::Config.logger_worker,
              BawWorkers::Config.file_info,
              valid_audio_formats,
              config_file_name)

          # enqueue to resque
          to_do_path = BawWorkers::Settings.actions.harvest.to_do_path

          gather_files.directory(to_do_path)
        end

      end

      # Perform method used by resque-status.
      def perform
        harvest_params = options['harvest_params']
        self.class.action_perform(harvest_params)
      end

    end
  end
end