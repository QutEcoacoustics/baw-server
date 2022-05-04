# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Eventually deletes a uploaded file after a period of time.
      # For safety we keep a copy of harvested files for a week.
      class DeleteHarvestItemFileJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.harvest.queue
        perform_expects Integer

        def self.delete_after
          Settings.actions.harvest.delete_after.seconds
        end

        def self.delete_later(harvest_item, wait: nil)
          wait ||= delete_after
          DeleteHarvestItemFileJob.set(wait:).perform_later(harvest_item.id)
        end

        def perform(harvest_item_id)
          harvest_item = HarvestItem.find(harvest_item_id)
          logger.info('Preparing to delete harvest item file', harvest_item_id:, path: harvest_item.path)

          if harvest_item.file_deleted?
            logger.info('Harvest item already deleted', harvest_item:)
            return
          end

          unless harvest_item.completed?
            logger.info('Harvest item not completed, will not delete, trying again later', harvest_item:)
            DeleteHarvestItemFileJob.delete_later(harvest_item)
          end

          harvest_item.delete_file!
          logger.info('Harvest item file deleted', path: harvest_item.path)
        rescue StandardError => e
          harvest_item&.add_to_error(e.message)
          raise
        ensure
          harvest_item&.save
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_uuid(self)
        end

        def name
          "DeleteHarvestItemFileJob:#{arguments.first}"
        end
      end
    end
  end
end
