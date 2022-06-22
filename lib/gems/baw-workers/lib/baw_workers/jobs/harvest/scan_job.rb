# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Scans a harvest directory for any files that might have been missed by webhooks.
      class ScanJob < BawWorkers::Jobs::ApplicationJob
        include BawWorkers::Jobs::StampUser

        queue_as Settings.actions.harvest_scan.queue
        perform_expects Integer

        #retry_on StandardError, attempts: 3

        # @param harvest [::Harvest]
        def self.scan(harvest)
          raise unless harvest.is_a?(::Harvest)

          perform_later(harvest.id)
        end

        def perform(harvest_id)
          # @type [::Harvest]
          harvest = ::Harvest.find(harvest_id)
          logger.info('Preparing to scan harvest directory', harvest_id:, path: harvest.upload_directory)

          found = logger.measure_info('File scan finished') {
            scan_for_files(harvest)
          }

          logger.info('Transitioning to metadata extraction', harvest_id:, found:)

          # finally transition to metadata extraction
          harvest.extract!
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(self, { id: arguments[0] })
        end

        def name
          "ScanForHarvest:#{arguments.first}"
        end

        def skip_dir?(name)
          name.start_with?('.') || name == 'System Volume Information'
        end

        def skip_file?(name)
          # including .DS_STORE files in particular
          name.start_with?('.') || name == 'Thumbs.db'
        end

        def scan_for_files(harvest)
          root = Settings.root_to_do_path
          target = harvest.upload_directory
          found = 0

          # scan for files
          target.find do |path|
            # skip some well know files and folders we never want to process
            basename = path.basename.to_s
            if path.directory?
              # don't descend into this directory
              Find.prune if skip_dir?(basename)
              # regardless we don't want to enqueue any directory only files within them
              #logger.debug('Skipping directory', path:)

              next
            elsif skip_file?(basename)
              #logger.debug('Skipping file', path:)
              next
            end

            rel_path = path.relative_path_from(root)

            #logger.debug('Processing file', path:, rel_path:)

            # scans are only ever done before the metadata extraction phase
            HarvestJob.enqueue_file(
              harvest,
              rel_path,
              should_harvest: false,
              debounce_on_recent_metadata_extraction: true
            )
            found += 1
          end

          found
        end
      end
    end
  end
end
