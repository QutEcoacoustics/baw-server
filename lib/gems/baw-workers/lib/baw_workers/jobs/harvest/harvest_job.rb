# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # gathers metadata about a file for and then harvests it
      class HarvestJob < BawWorkers::Jobs::ApplicationJob
        class << self
          # Schedule a harvest job for a harvest item
          # @param harvest [Harvest] the parent harvest
          # @param rel_path [String] the path within harvester_to_do to process
          # @param should_harvest [Boolean] whether or not to actually process the file
          # @return [Boolean] status of job enqueue, true if successful
          def enqueue_file(harvest, rel_path, should_harvest:)
            item = new_harvest_item(harvest, rel_path)

            result = perform_later!(item.id, should_harvest)
            success = result != false
            logger.debug('enqueued file', path: rel_path, id: item.id, success:, job_id: (result || nil)&.job_id)

            success
          end

          private

          # @param harvest [Harvest]
          # @param rel_path [String] the path within harvester_to_do to process
          def new_harvest_item(harvest, rel_path)
            # sanity check
            unless harvest.path_within_harvest_dir(rel_path)
              raise ArgumentError, "#{rel_path} is not in the correct harvest directory"
            end

            # don't store any info, we're going to calculate it when the job runs
            item = HarvestItem.new(
              path: rel_path,
              status: HarvestItem::STATUS_NEW,
              uploader_id: harvest.creator_id,
              info: {},
              harvest:
            )

            # sanity check
            raise ArgumentError, "#{item.absolute_path} does not exist" unless item.absolute_path.exist?

            item.save!

            logger.debug('harvest item created', harvest_item_id: item.id)

            item
          end
        end

        queue_as Settings.actions.harvest.queue
        perform_expects Integer, [TrueClass, FalseClass]

        include SemanticLogger::Loggable

        [
          [:process_steps, 'processing steps finished'],
          [:simple_validations, 'basic validating'],
          [:apply_fixes, 'applying fixes'],
          [:extract_metadata, 'extrating metadata'],
          [:validate, 'validate file'],
          [:pre_process, 'pre process file'],
          [:harvest_file, 'harvest file'],
          [:post_process, 'post process file']
        ].each do |name, message|
          logger_measure_method(name, level: :debug, message:, log_exception: :none)
        end

        FIXES = [
          Emu::Fix::BAR_LT_DURATION_BUG
        ].freeze

        # @return [HarvestItem] The database record for the current harvest item
        attr_reader :harvest_item

        # @return [Harvest] The database record for the current harvest
        attr_reader :harvest

        # Gather metadata about a file and potentially harvest it
        # @param harvest_item_id [Integer]
        # @param should_harvest [Boolean] whether or not to actually process the file
        def perform(harvest_item_id, should_harvest)
          load_records(harvest_item_id)

          SemanticLogger.tagged(harvest_item_id:) do
            process_steps(should_harvest)
          end
        end

        # Produces a sensible name for this payload.
        # Should be unique but does not need to be. Has no operational effect.
        # This value is only used when the status is updated by resque:status.
        def name
          id, should_harvest = arguments
          "HarvestItem(#{id}), should_harvest: #{should_harvest}"
        end

        def create_job_id
          # duplicate jobs should be detected
          ::BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(self, 'harvest_job')
        end

        private

        # the main workflow for a harvest
        # @param should_harvest [Boolean] whether or not to actually process the file
        def process_steps(should_harvest)
          simple_validations

          # All of the simple validations are basic requiments for processing a file.
          # Does it exist? Does it have more than 0 bytes? Is it a target extensions?
          # No point advancing if these conditions are not met.
          unless valid?
            move_to_failed
            return
          end

          # I didn't want to mutate files in the information gathering stage.
          # However, unless fixes are applied it is really hard to gather
          # correct metadata for the file - which is needed for validating.
          # Lastly, EMU is meant to be safe and fault tolerant so we're just
          # Hoping it is up to the task.
          apply_fixes

          extract_metadata

          validate

          mark_status(HarvestItem::STATUS_METADATA_GATHERED)

          # stop here if we're only gathering metadata
          return unless should_harvest

          # fix any errors or manipulate the files before harvest
          # any files we know we can't harvest should be removed from consideration in this step
          pre_process

          # we're trying to do an actual harvest but there are still validation errors; fail time
          move_to_failed unless valid?

          harvest_file

          post_process

          mark_status(HarvestItem::STATUS_COMPLETED)
        rescue StandardError => e
          move_to_error(e)

          # only raise on true exceptions rather than our logical errors
          raise unless one_of_our_exceptions(e)

          # mark this job as failed in our job-status tracker as well
          failed!(e.message)
        ensure
          save_state
        end

        def mark_status(status)
          harvest_item.status = status
          logger.info('Harvest item status changed', status: harvest_item.status)
        end

        def move_to_failed
          logger.warn('Halting harvest; record is not valid')
          mark_status(HarvestItem::STATUS_FAILED)
        end

        def move_to_error(exception)
          logger.error(name, exception:)
          mark_status(HarvestItem::STATUS_ERRORED)
          harvest_item.info = harvest_item.info.new(error: exception.message)
        end

        def save_state
          logger.info('Saving harvest item', status: harvest_item.status)
          harvest_item.save!
        end

        def load_records(harvest_item_id)
          # TODO: special case failure here? the item could be deleted?
          @harvest_item = HarvestItem.find(harvest_item_id)

          logger.info('Loaded harvest item', status: harvest_item.status, id: harvest_item.id)

          # only harvest items made with new code should be executing this job,
          # so harvest should always be non-null
          @harvest = harvest_item.harvest
          raise 'No harvest record found' if harvest.nil?
        end

        def simple_validations
          # results will be an array of either nils (no problem) or ValidationResult records
          results = Validations.validate(Validations.simple_validations, harvest_item)

          # intentionally reset validations here
          harvest_item.info = harvest_item.info.new(validations: results.compact)
        end

        def apply_fixes
          file_path = harvest_item.absolute_path
          fix_log = FIXES.map { |fix_id|
            logger.debug('Checking if fix needed', fix_id:)
            result = Emu::Fix.fix_if_needed(file_path, fix_id)
            raise 'Failed running EMU, see logs' if result&.success? != true

            # return the fix log for the file
            result.records.first
          }

          harvest_item.info = harvest_item.info.new(fixes: harvest_item.info.fixes + fix_log)
        end

        def extract_metadata
          # this hash replaces most of the information traditionally gathered from harvest.yml files
          directory_info = harvest.find_mapping_for_path(harvest_item.path)

          path = harvest_item.absolute_path

          basic_info = file_info_service.basic(path)
          advanced_info = file_info_service.advanced(path, directory_info&.utc_offset, throw: false)
          audio_info = file_info_service.audio_info(path)

          directory_info
            .to_h
            .merge({
              uploader_id: harvest.creator_id,
              notes: {}
            })
            .merge(basic_info)
            .merge(advanced_info)
            .merge(audio_info)
            .except(:raw, :separator, :file, :errors, :file_path) => file_info

          harvest_item.info = harvest_item.info.new(file_info:)
        end

        def validate
          # results will be an array of either nils (no problem) or ValidationResult records
          results = Validations.validate(Validations.after_extract_metadata_validations, harvest_item)

          harvest_item.info = harvest_item.info.new(
            validations: harvest_item.info.validations + results.compact
          )
        end

        def valid?
          harvest_item.info.validations.empty?
        end

        def preprocess
          log.debug('No pre-process step currently defined, skipping')
        end

        def harvest_file
          # TODO
        end

        def post_process
          log.debug('No post-process step currently defined, skipping')
        end

        def one_of_our_exceptions(error)
          return true if error.class.name =~ /BawAudioTools::Exceptions/
          return true if error.class.name =~ /BawWorkers::Exceptions/

          # more to come
          false
        end

        # @return [BawWorkers::FileInfo]
        def file_info_service
          BawWorkers::Config.file_info
        end
      end
    end
  end
end
