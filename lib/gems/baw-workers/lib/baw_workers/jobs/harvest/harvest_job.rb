# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # gathers metadata about a file for and then harvests it
      class HarvestJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.harvest.queue
        perform_expects Integer, [TrueClass, FalseClass]

        class << self
          # Schedule a harvest job for a harvest item
          # @param harvest [Harvest] the parent harvest
          # @param rel_path [String,Pathname] the path within harvester_to_do to process
          #    (a path relative to the harvester_to_do directory)
          # @param should_harvest [Boolean] whether or not to actually process the file
          # @param debounce_on_recent_metadata_extraction [Boolean]
          #    IFF:
          #      - param is true
          #      - and {should_harvest} is false
          #      - a current harvest items exists
          #      - and the item is in the state of metadata_gathered
          #      -  it was last updated after the current harvest entered an upload stat
          #    then this job will not be enqueued.
          # @return [Boolean] status of job enqueue, true if successful
          def enqueue_file(harvest, rel_path, should_harvest:, debounce_on_recent_metadata_extraction: false)
            rel_path = rel_path.to_s if rel_path.is_a?(Pathname)

            # try and find an existing record
            item = existing_harvest_item(harvest, rel_path)

            if recently_had_metadata_gathered?(harvest, item, should_harvest:, debounce_on_recent_metadata_extraction:)
              logger.debug('Not enqueuing job; recently had metadata gathered')
              return false
            end

            # otherwise create a new one
            item = new_harvest_item(harvest, rel_path) if item.nil?

            # we never want to harvest a completed item again
            if is_completed?(item)
              logger.warn('Not enqueuing job; item is already completed', item_id: item.id, path: item.path)
              return false
            end

            # It used to be that we updated this only if the job enqueue was successful
            # but it's more important to signal that work needs to be done and then enqueue more jobs later when the
            # enqueue will work.
            # TODO: Harvest might need some manual machine pumping mechanism to re-enqueue jobs if they're stuck on new
            item.update_attribute(:status, HarvestItem::STATUS_NEW)

            success, job = enqueue(item.id, should_harvest:)

            logger.debug('enqueued file', path: item.path, id: item.id, success:, job_id: (job || nil)&.job_id)
          end

          # @param id [Integer] the id of the harvest item to enqueue
          # @param should_harvest [Boolean] whether or not to do a full harvest or just extract metadata
          # @return [Array(Boolean, (BawWorkers::Jobs::Harvest::HarvestJob, nil))] return [success as a bool, the created job (or nil)]
          def enqueue(id, should_harvest:)
            result = perform_later(id, should_harvest) { |job|
              next if job.successfully_enqueued?
              # if the enqueue fails because the job is already in the queue then we don't care
              # otherwise throw an error
              raise "Failed to enqueue harvest item with id #{id}" if job.unique?
            }
            [result != false, result]
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

          def existing_harvest_item(harvest, rel_path)
            result = HarvestItem.find_by(path: rel_path, harvest:)

            logger.debug('found existing harvest item', harvest_item_id: result.id) unless result.nil?

            result
          end

          # @param harvest [Harvest]
          # @param harvest_item [HarvestItem]
          # @param should_harvest [Boolean]
          # @param debounce_on_recent_metadata_extraction [Boolean]
          # @return [Boolean]
          def recently_had_metadata_gathered?(harvest, harvest_item, should_harvest:,
                                              debounce_on_recent_metadata_extraction:)
            return false unless debounce_on_recent_metadata_extraction

            return false if should_harvest

            return false if harvest_item.nil?

            return false unless harvest_item.metadata_gathered?

            harvest_item.updated_at > harvest.last_upload_at
          end

          def is_completed?(harvest_item)
            harvest_item&.completed?
          end
        end

        include SemanticLogger::Loggable

        [
          [:process_steps, 'processing steps finished'],
          [:simple_validations, 'basic validating completed'],
          [:apply_fixes, 'applied fixes'],
          [:extract_metadata, 'extracting metadata'],
          [:validate, 'validated file'],
          [:pre_process, 'pre-processed file'],
          [:create_audio_recording, 'created audio recording'],
          [:harvest_file, 'harvested file'],
          [:post_process, 'post-processed file']
        ].each do |name, message|
          logger_measure_method(name, level: :debug, message:, log_exception: :none)
        end

        FIXES = [
          Emu::Fix::FL_PARTIAL_FILE,
          Emu::Fix::FL_DURATION_BUG,
          Emu::Fix::FL_PREALLOCATED_HEADER,
          Emu::Fix::FL_SPACE_IN_DATESTAMP,
          Emu::Fix::FL_INCORRECT_DATA_SIZE,
          Emu::Fix::FL_DATA_SIZE_0,
          Emu::Fix::WA_NO_DATA
        ].freeze

        # @return [::HarvestItem] The database record for the current harvest item
        attr_reader :harvest_item

        # @return [::Harvest] The database record for the current harvest
        attr_reader :harvest

        # @return [::AudioRecording] the audio recording for this harvest item
        attr_reader :audio_recording

        # Gather metadata about a file and potentially harvest it
        # @param harvest_item_id [Integer]
        # @param should_harvest [Boolean] whether or not to actually process the file
        def perform(harvest_item_id, should_harvest)
          load_records(harvest_item_id)

          process_steps(should_harvest)
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
          ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(self, {
            item: arguments[0],
            should_harvest: arguments[1]
          }, 'harvest_job')
        end

        private

        # the main workflow for a harvest
        # @param should_harvest [Boolean] whether or not to actually process the file
        def process_steps(should_harvest)
          bump_version

          simple_validations

          # All of the simple validations are basic requirements for processing a file.
          # Does it exist? Does it have more than 0 bytes? Is it a file included in our target extensions?
          # No point advancing if these conditions are not met.
          return move_to_failed unless valid?

          # I didn't want to mutate files in the information gathering stage.
          # However, unless fixes are applied it is really hard to gather
          # correct metadata for the file - which is needed for validating.
          # Lastly, EMU is meant to be safe and fault tolerant so we're just
          # Hoping it is up to the task.
          apply_fixes

          # EMU can detect some unfixable problems
          return move_to_failed unless valid?

          extract_metadata

          validate

          mark_status(HarvestItem::STATUS_METADATA_GATHERED)

          # stop here if we're only gathering metadata
          return unless should_harvest

          # we're trying to do an actual harvest but there are still validation errors; fail time
          return move_to_failed unless valid?

          # fix any errors or manipulate the files before harvest
          pre_process

          # create the audio recording in the database
          return move_to_failed unless create_audio_recording

          # harvest the file ( move the file on disk)
          return move_to_failed unless harvest_file

          post_process

          mark_status(HarvestItem::STATUS_COMPLETED)
        rescue StandardError => e
          move_to_error(e)

          # Two cases here:
          # 1. Truly exceptional behaviour, such as a bug in the code. Raise and send an error notification.
          # 2. Some kind of domain/logical/transient error. Timeouts are a good example.
          #    - Do not send a notification.
          #    - Maybe it can be retried?

          # here we detect exceptions that should trigger a retry
          raise if should_retry?(e)

          # raise will mark the job tracker as :errored
          raise unless one_of_our_exceptions(e)

          # otherwise, set the job-tracker to :failed indicating retry is possible
          failed!(e.message)
        ensure
          save_state
        end

        RETRY_ERRORS = [
          Net::OpenTimeout,
          Net::ReadTimeout,
          Timeout::Error,
          BawAudioTools::Exceptions::AudioToolTimedOutError
        ].freeze

        retry_on(*RETRY_ERRORS)

        def should_retry?(error)
          should = RETRY_ERRORS.any? { |e| error.instance_of?(e) }

          if should
            # reset the jobs status as new so the harvest knows items are outstanding
            mark_status(HarvestItem::STATUS_NEW)
            logger.warn("Scheduled job to be retried because of error: #{error.class.name}:#{error.message}")
          end

          should
        end

        def one_of_our_exceptions(error)
          return true if error.class.name =~ /BawAudioTools::Exceptions/
          return true if error.class.name =~ /BawWorkers::Exceptions/

          # more to come
          false
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
          logger.error('Harvest failed', message: exception.message)
          mark_status(HarvestItem::STATUS_ERRORED)
          harvest_item.add_to_error(exception.message)
        end

        def save_state
          logger.info('Saving harvest item', status: harvest_item.status)
          harvest_item.save!
        end

        def load_records(harvest_item_id)
          begin
            @harvest_item = HarvestItem.find(harvest_item_id)
          rescue ::ActiveRecord::RecordNotFound => e
            logger.error('Harvest item not found', id: harvest_item_id)
            # failed throws here and halts execution
            failed!("Harvest item #{harvest_item_id} not found", e.message)
          end

          logger.debug('Loaded harvest item', status: harvest_item.status, id: harvest_item.id)

          # only harvest items made with new code should be executing this job,
          # so harvest should always be non-null
          @harvest = harvest_item.harvest
          logger.debug('Loaded harvest', harvest:)
          raise 'No harvest record found' if harvest.nil?
        end

        def bump_version
          harvest_item.info = harvest_item.info.new(version: harvest_item.info.version + 1)
        end

        def simple_validations
          # results will be an array of either nils (no problem) or ValidationResult records
          results = Validations.validate(Validations.simple_validations, harvest_item)

          # intentionally reset validations here
          harvest_item.info = harvest_item.info.new(validations: results.compact)
        end

        def apply_fixes
          file_path = harvest_item.absolute_path
          logger.measure_debug('Fixing file with emu') do
            Emu::Fix.apply(file_path, *FIXES)
          end => result

          raise "Failed running EMU: #{result.log}" unless result&.success?

          # only one file checked so only one result in the array
          fix_log = result.records.first

          raise "fix_log is nil: #{result.to_json}" if fix_log.nil?

          # if the file was renamed update harvest item path
          if fix_log[:file] != file_path
            new_path = HarvestItem.path_from_absolute_path(Pathname(fix_log[:file]))
            harvest_item.path = new_path

            raise "Path does not exist #{harvest_item.absolute_path}" unless harvest_item.absolute_path.exist?
          end

          # convert any serious modifications into a validation
          validations = fix_log[:problems].map { |id, details|
            # affected means the file has the problem
            # we just tried to fix problems... if the fix didn't work...
            # TODO: differentiate on severity?
            next unless [Emu::Fix::STATUS_RENAMED, Emu::Fix::STATUS_NOT_FIXED].include?(details[:status])

            message = details.fetch(:message, nil).blank? ? '' : details[:message].to_s
            BawWorkers::Jobs::Harvest::ValidationResult.new(
              name: id.downcase,
              status: BawWorkers::Jobs::Harvest::ValidationResult::STATUS_NOT_FIXABLE,
              message: "#{details[:check_result][:message]}. #{message}"
            )
          }

          # we don't need to save the file or backup_file fields - they're redundant
          fix_log = fix_log.except(:file, :backup_file).merge({ version: harvest_item.info.version })

          harvest_item.info = harvest_item.info.new(
            fixes: harvest_item.info.fixes + [fix_log],
            validations: harvest_item.info.validations + validations.compact
          )
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
              notes: {
                relative_path: harvest_item.path
              }
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

        def pre_process
          logger.debug('No pre-process step currently defined, skipping')
          # TODO: wac processing? Flac conversion?
        end

        # @return [Boolean]
        def create_audio_recording
          result = catch(:halt) {
            # if we're retrying this harvest the audio recording might already exist
            if harvest_item.audio_recording_id
              logger.debug('Audio recording already exists, fetching',
                audio_recording_id: harvest_item.audio_recording_id)

              @audio_recording = AudioRecording.find(harvest_item.audio_recording_id)
              harvest_item.audio_recording_id = audio_recording.id
              return true
            end

            # use the transaction to ensure that if the recording is created
            # then the associated harvest item is updated too
            # and also that any other records modified by the overlap fix are reverted on failure.
            create_draft_audio_recording
            audio_recording.set_uuid
            ::ActiveRecord::Base.transaction do
              raise 'Record should not saved yet' unless audio_recording.new?

              # save the result
              audio_recording.status = AudioRecording::STATUS_NEW

              # check we have a valid record
              unless audio_recording.validate
                error = "Audio recording is not valid: #{audio_recording.errors.map(&:full_message).join(', ')}"
                harvest_item.add_to_error(error)
                throw :halt
              end

              # save the record
              audio_recording.save!
              harvest_item.audio_recording_id = audio_recording.id

              fix_overlaps(audio_recording)
            end

            return true
          }

          harvest_item.audio_recording_id = nil if result != true

          result == true
        rescue StandardError
          # the harvest item gets saved with exception information
          # if we fail to unset this we'd violate a foreign key constraint when the harvest item is saved
          # because the audio recording does not exist
          harvest_item.audio_recording_id = nil
          raise
        end

        # @return [Boolean] true if the operation succeeded
        def harvest_file
          # sanity checks
          raise 'Audio recording was nil' if audio_recording.nil?
          raise 'Audio recording has not yet been saved' if audio_recording.new_record?

          begin
            audio_recording.status = AudioRecording::STATUS_UPLOADING
            audio_recording.save!

            # start moving the file
            copy_file(audio_recording)

            # sanity check
            raise 'Cant find file after moving' unless audio_recording.original_file_exists?

            # mark the record as complete
            audio_recording.status = AudioRecording::STATUS_READY
          rescue StandardError
            audio_recording.status = AudioRecording::STATUS_ABORTED
            raise
          ensure
            audio_recording&.save
          end
        end

        def post_process
          # delete the source file
          DeleteHarvestItemFileJob.delete_later(harvest_item)

          # Enqueue a job to update any analysis jobs that are ongoing
          # We only do this for streaming harvests because non-streaming harvests
          # run this job at the end of the harvest.
          # This may fail due to the unique job id constraint, but that's fine,
          # because each job is idempotent and will include all previous recordings
          # in each amend.
          harvest.enqueue_amend_analysis_jobs if harvest.streaming_harvest?
        end

        def create_draft_audio_recording
          file_info = harvest_item.info.file_info
          @audio_recording = AudioRecording.new(
            uploader_id: harvest.creator_id,
            recorded_date: ensure_time(file_info[:recorded_date]),
            site_id: file_info[:site_id],
            duration_seconds: file_info[:duration_seconds],
            sample_rate_hertz: file_info[:sample_rate_hertz],
            channels: file_info[:channels],
            bit_rate_bps: file_info[:bit_rate_bps],
            media_type: file_info[:media_type],
            data_length_bytes: file_info[:data_length_bytes],
            file_hash: file_info[:file_hash],
            notes: file_info[:notes],
            creator_id: harvest.creator_id,
            original_file_name: file_info[:file_name],
            recorded_utc_offset: file_info[:utc_offset]
          )
        end

        # @param time_string [Time,String,nil]
        # @return [Time, nil]
        def ensure_time(time_or_string)
          return nil if time_or_string.blank?

          return time_or_string if time_or_string.is_a?(Time)

          Time.zone.parse(time_or_string)
        end

        # @param [AudioRecording] audio_recording
        # @return [Pathname] the new location of the file
        def copy_file(audio_recording)
          helper = BawWorkers::Config.original_audio_helper

          options = {
            uuid: audio_recording.uuid,
            original_format: Mime::Type.file_extension_of(audio_recording.media_type)
          }
          final_name = helper.file_name_uuid(options)

          helper
            .possible_paths_file(options, final_name)
            .map { |path| Pathname.new(path) } => possible_paths

          old_path = harvest_item.absolute_path
          new_path = logger.measure_info('Copying file') {
            file_info_service.copy_to_any(old_path, possible_paths)
          }

          logger.info('Copied file', old_path:, new_path:)
          new_path
        end

        # @param [AudioRecording] audio_recording
        def fix_overlaps(audio_recording)
          # check for overlaps and attempt to fix
          overlap_result = audio_recording.fix_overlaps

          too_many = overlap_result ? overlap_result[:overlap][:too_many] : false
          not_fixed = overlap_result ? overlap_result[:overlap][:items].any? { |info| !info[:fixed] } : false

          logger.debug('overlap fix', overlap_result:)

          if too_many
            harvest_item.add_to_error("Too many overlapping recordings#{{ error_info: overlap_result }.to_json}")
          end

          if not_fixed
            harvest_item.add_to_error("Some overlaps could not be fixed#{{ error_info: overlap_result }.to_json}")
          end

          throw :halt if too_many || not_fixed
        end

        # @return [BawWorkers::FileInfo]
        def file_info_service
          BawWorkers::Config.file_info
        end
      end
    end
  end
end
