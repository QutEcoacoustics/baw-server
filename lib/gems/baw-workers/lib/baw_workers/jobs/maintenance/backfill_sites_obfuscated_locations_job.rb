# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Maintenance
      # Backfills obfuscated locations for sites that have coordinates but no obfuscated coordinates.
      # This job processes sites in batches to avoid memory issues and can be safely re-run.
      #
      # Usage:
      #   BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.perform_later
      #
      class BackfillSitesObfuscatedLocationsJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.maintenance.queue

        perform_expects

        def perform
          logger.info('Starting backfill of obfuscated locations for sites')

          updated = 0
          failed = 0

          sites_to_update.find_each do |site|
            backfill_site(site)
            updated += 1
          rescue StandardError => e
            failed += 1
            logger.error("Failed to update site #{site.id}", exception: e)
          end

          logger.info('Backfill complete', updated:, failed:)

          { updated:, failed: }
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_timestamp(self)
        end

        def name
          job_id
        end

        private

        # Find sites that have coordinates but no obfuscated coordinates
        # and where the obfuscated location is system-generated (not user-provided)
        def sites_to_update
          sites = Site.arel_table

          sites[:obfuscated_latitude].eq(nil).and(sites[:latitude].not_eq(nil))
            .or(
            sites[:obfuscated_longitude].eq(nil).and(sites[:longitude].not_eq(nil))
          ) => predicate

          Site
            .where(custom_obfuscated_location: false)
            .where(predicate)
        end

        def backfill_site(site)
          # Directly call update_obfuscated_location since the callback only fires
          # when latitude/longitude changes. For backfill, we need to generate
          # obfuscated values for existing coordinates.
          site.update_obfuscated_location unless site.custom_obfuscated_location
          site.save!(touch: false)

          if site.latitude.present? && site.obfuscated_latitude.nil?
            raise "Obfuscated latitude not set for site #{site.id}"
          end

          if site.longitude.present? && site.obfuscated_longitude.nil? # rubocop:disable Style/GuardClause
            raise "Obfuscated longitude not set for site #{site.id}"
          end
        end
      end
    end
  end
end
