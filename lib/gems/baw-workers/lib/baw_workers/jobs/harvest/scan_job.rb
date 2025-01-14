# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Scans a harvest directory for any files that might have been missed by webhooks.
      class ScanJob < BawWorkers::Jobs::ApplicationJob
        include BawWorkers::ActiveJob::StampUser
        include PathFilter

        queue_as Settings.actions.harvest_scan.queue
        perform_expects Integer

        retry_on StandardError, attempts: 3, wait: 0

        # @param harvest [::Harvest]
        def self.scan(harvest)
          raise unless harvest.is_a?(::Harvest)

          perform_later(harvest.id)
        end

        def perform(harvest_id)
          # @type [::Harvest]
          harvest = ::Harvest.find(harvest_id)
          logger.info('Preparing to scan harvest directory', harvest_id:, path: harvest.upload_directory)

          found = logger.measure_info('File scan finished', on_exception_level: :error) {
            scan_for_files(harvest)
          }

          logger.info('Transitioning to metadata extraction', harvest_id:, found:)

          # no need to transition in streaming harvest
          return if harvest.streaming_harvest?

          # reload to prevent race conditions
          # https://github.com/QutEcoacoustics/baw-server/issues/613
          harvest.reload

          # sometimes the harvest may have been cancelled while were waiting
          # https://github.com/QutEcoacoustics/baw-server/issues/615
          return unless harvest.may_extract?

          # finally transition to metadata extraction
          harvest.extract!
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(self, { id: arguments[0] })
        end

        def name
          "ScanForHarvest:#{arguments.first}"
        end

        # @param harvest [::Harvest]
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

            # For batch harvests: scans are only ever done before the metadata
            # extraction phase
            # For streaming harvests: a scan could be done any time
            should_harvest = harvest.streaming_harvest?
            # similarly, we only care about debouncing extra metadata gathers for
            # a batch harvest
            debounce_on_recent_metadata_extraction = harvest.batch_harvest?

            HarvestJob.enqueue_file(
              harvest,
              rel_path,
              should_harvest:,
              debounce_on_recent_metadata_extraction:
            )
            found += 1
          end

          found
        end
      end
    end
  end
end
