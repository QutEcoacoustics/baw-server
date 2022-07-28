# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Scans a harvest directory for any files that might have been missed by webhooks.
      class ReenqueueJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.harvest_scan.queue
        perform_expects Integer, [TrueClass, FalseClass]

        #retry_on StandardError, attempts: 3

        # Enqueue many harvest items for processing all at once.
        # It will reset all harvest items to a status of :new before the job is enqueued!
        # @param harvest [Harvest]
        # @param should_harvest [Boolean] whether or not to do a full harvest or just extract metadata
        def self.enqueue!(harvest, should_harvest:)
          raise unless harvest.is_a?(::Harvest)

          # warning: ensure the semantics of this method largely match that of
          # the other enqueue methods in this HarvestJob!

          # this query does the select on the db server and the update on the server
          # we never need to deserialize the rows or create HarvestItem models
          harvest
            .harvest_items
            .where(HarvestItem.arel_table[:status] != HarvestItem::STATUS_COMPLETED)
            .update_all(
              status: HarvestItem::STATUS_NEW,
              updated_at: Time.now
            )

          perform_later(harvest.id, should_harvest)
        end

        def perform(harvest_id, should_harvest)
          # @type [::Harvest]
          harvest = ::Harvest.find(harvest_id)
          logger.info('Reenqueue all harvest items', harvest_id:)

          ids = logger.measure_info('Query for harvest items complete') {
            # this query returns an array of ints, again, ideally never creating HarvestItem models
            harvest
              .harvest_items
              .where(HarvestItem.arel_table[:status] == HarvestItem::STATUS_NEW)
              .pluck(:id)
          }

          # finally enqueue the jobs
          logger.measure_info('Jobs enqueued') {
            ids.each do |id|
              BawWorkers::Jobs::Harvest::HarvestJob.enqueue(id, should_harvest:)
            end
          }
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_uuid(self)
        end

        def name
          "ReenqueueForHarvest:#{arguments.first},should_harvest:#{arguments.second}"
        end
      end
    end
  end
end
