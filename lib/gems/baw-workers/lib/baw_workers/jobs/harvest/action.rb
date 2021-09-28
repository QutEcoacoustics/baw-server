# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Harvests audio files to be accessible via baw-server.
      class Action < BawWorkers::Jobs::ApplicationJob
        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        queue_as Settings.actions.harvest.queue
        perform_expects Integer, String

        # Perform work. Used by Resque.
        # @param [Integer] harvest_id
        # @param [String] harvest_path
        # @return [Array<Hash>] array of hashes representing operations performed
        def perform(harvest_id, rel_path)
          item = HarvestItem.find(harvest_id)

          action_run(item, rel_path)
        end

        # @return [Array<Hash>] array of hashes representing operations performed
        def action_run(item, path)
          real_path = Enqueue.root_to_do_path / path
          item.info ||= {}

          logger.info('Started harvest')

          begin
            # get the basic info from the file again

            gather_files = Enqueue.create_gather_files
            # TODO: this will need to be fixed, root to do path allows a job to get harvest.ymls for files outside
            # of the scope for which it was enqueued
            file_info = gather_files.file(real_path, Enqueue.root_to_do_path, {})
            item.info[:file_info] = file_info

            unless file_info.values_at(:project_id, :site_id, :uploader_id).all?
              raise BawWorkers::Exceptions::HarvesterError,
                'Missing one or more values for :project_id, :site_id, or :uploader_id'
            end

            result = action_single_file.run(file_info, true, false, harvest_item: item)
          rescue StandardError => e
            logger.error(name, exception: e)

            item.info[:error] = e.message
            item.status = one_of_our_exceptions(e) ? HarvestItem::STATUS_FAILED : HarvestItem::STATUS_ERRORED
            item.save!
            failed!(e.message)
          end

          logger.info('Completed harvest', result: result)
          item.info[:error] = nil
          item.status = HarvestItem::STATUS_COMPLETED
          item.save
          result
        end

        def one_of_our_exceptions(error)
          return true if error.class.name =~ /BawAudioTools::Exceptions/
          return true if error.class.name =~ /BawWorkers::Exceptions/

          # more to come
          false
        end

        # Enqueue a single file for harvesting.
        # @param [Hash] harvest_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def self.action_enqueue(harvest_params)
          result = BawWorkers::Jobs::Harvest::Action.create(harvest_params: harvest_params)
          BawWorkers::Config.logger_worker.info(name) do
            "Job enqueue returned '#{result}' using #{harvest_params}."
          end
          result
        end

        # Create a BawWorkers::Jobs::Harvest::SingleFile instance.
        # @return [BawWorkers::Jobs::Harvest::SingleFile]
        def action_single_file
          BawWorkers::Jobs::Harvest::SingleFile.new(
            BawWorkers::Config.logger_worker,
            BawWorkers::Config.file_info,
            BawWorkers::Config.api_communicator,
            BawWorkers::Config.original_audio_helper
          )
        end

        # Produces a sensible name for this payload.
        # Should be unique but does not need to be. Has no operational effect.
        # This value is only used when the status is updated by resque:status.
        def name
          id, path = arguments
          "HarvestItem(#{id}) for: #{path}"
        end

        def create_job_id
          # duplicate jobs should be detected
          ::BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(self, 'harvest_job')
        end
      end
    end
  end
end
