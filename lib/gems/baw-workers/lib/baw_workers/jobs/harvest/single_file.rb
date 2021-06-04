# frozen_string_literal: true

module BawWorkers
  module Harvest
    # Get a list of files to be harvested.
    class SingleFile
      attr_accessor :logger, :file_info_helper, :api_comm

      # Create a new BawWorkers::Harvest::SingleFile.
      # @param [Logger] logger
      # @param [BawWorkers::FileInfo] file_info_helper
      # @param [BawWorkers::ApiCommunicator] api_comm
      # @param [BawWorkers::Storage::AudioOriginal] original_audio
      # @return [BawWorkers::Harvest::SingleFile]
      def initialize(logger, file_info_helper, api_comm, original_audio)
        @logger = logger
        @file_info_helper = file_info_helper
        @api_comm = api_comm
        @original_audio = original_audio

        @class_name = self.class.name
      end

      # Process a single audio file.
      # @param [Hash] file_info_hash
      # @param [Boolean] is_real_run
      # @param [Boolean] copy_on_success
      # @return [Array<String>] existing target paths
      def run(file_info_hash, is_real_run, copy_on_success = false)
        file_info_hash.deep_symbolize_keys!

        project_id = file_info_hash[:project_id]
        site_id = file_info_hash[:site_id]
        uploader_id = file_info_hash[:uploader_id]
        file_path = file_info_hash[:file_path]
        file_format = File.extname(file_path).trim('.', '')

        @logger.info(@class_name) { "Processing #{file_path}..." }

        # check if file is empty or does not exist first
        # -----------------------------
        if !File.exist?(file_path)
          @logger.error(@class_name) { "File was not found #{file_path}" }
          raise BawAudioTools::Exceptions::FileNotFoundError, msg
        elsif File.size(file_path) < 1
          empty_file_new_name = rename_empty_file(file_path)
          msg = "File has no content (length of 0 bytes) renamed to #{File.basename(empty_file_new_name)} from #{file_path}"
          @logger.error(@class_name) { msg }
          raise BawAudioTools::Exceptions::FileEmptyError, msg
        end

        # construct file_info_hash for new audio recording request
        # -----------------------------
        audio_info_hash = get_audio_info_hash(file_info_hash, file_path)

        file_hash = audio_info_hash[:file_hash]

        # stop here if it is a dry run, shouldn't create a new recording
        # -----------------------------
        unless is_real_run
          @logger.info(@class_name) do
            "...finished dry run for #{file_path}: #{audio_info_hash}"
          end
          return []
        end

        # get auth token
        # -----------------------------
        security_info = get_security_info

        # Check uploader project access
        # -----------------------------
        access_result = get_access_result(project_id, site_id, uploader_id, security_info)

        # send request to create new audio recording entry on website
        # -----------------------------
        response_hash = get_new_audio_recording(file_path, project_id, site_id, audio_info_hash, security_info)

        audio_recording_id = response_hash['data']['id']
        audio_recording_uuid = response_hash['data']['uuid']
        audio_recording_recorded_date = response_hash['data']['recorded_date']

        # catch any errors after audio is created so status can be updated
        # -----------------------------

        harvest_completed_successfully = false

        begin
          # update audio recording status on website to uploading
          # description, file_to_process, audio_recording_id, update_hash, security_info
          update_status_uploading_result = @api_comm.update_audio_recording_status(
            'record pending file move',
            file_path,
            audio_recording_id,
            create_update_hash(audio_recording_uuid, file_hash, :uploading),
            security_info
          )

          # calculate target storage path using name with utc date
          storage_file_opts = {
            uuid: audio_recording_uuid,
            datetime_with_offset: Time.zone.parse(audio_recording_recorded_date),
            original_format: file_format
          }

          # Copy file to be harvested to well-known locations
          storage_target_paths = copy_to_well_known_paths(file_path, storage_file_opts)

          # Rename harvested file if copy was successful.
          existing_target_paths = rename_harvested_file(file_path, storage_target_paths)

          # update audio recording status on website to ready (skipping to_check for now)
          # TODO: set to_check so file has is checked independently
          @api_comm.update_audio_recording_status(
            'record completed file move',
            file_path,
            audio_recording_id,
            create_update_hash(audio_recording_uuid, file_hash, :ready),
            security_info
          )

          harvest_completed_successfully = true
        rescue StandardError => e
          msg = "Error after audio recording created on website, status set to aborted. Exception: #{e}"
          @logger.error(@class_name) { msg }
          @api_comm.update_audio_recording_status(
            'record error in harvesting',
            file_path,
            audio_recording_id,
            create_update_hash(audio_recording_uuid, file_hash, :aborted),
            security_info
          )
          raise e
        end

        # do this outside 'atomic' functionality above so that if
        # anything here fails, the harvest is still successful.
        # only run this if harvest was successful
        if harvest_completed_successfully

          # enqueue task to copy harvested file
          if copy_on_success
            source = File.expand_path(existing_target_paths[0])

            copy_base_path = Settings.actions.harvest.copy_base_path
            raw_destination = File.join(copy_base_path, create_relative_path(storage_file_opts))
            destination = File.expand_path(raw_destination)

            BawWorkers::Mirror::Action.action_enqueue(source, [destination])

            @logger.info(@class_name) { "Enqueued mirror task with source #{source} and destination #{destination}" }
          end

          # enqueue task to run analysis
          # BawWorkers::Analysis::Action.
        end

        @logger.info(@class_name) { "Finished processing #{file_path}: #{audio_info_hash}" }
        existing_target_paths
      end

      private

      def get_security_info
        security_info = @api_comm.request_login

        if security_info.blank?
          msg = 'Could not log in.'
          @logger.error(@class_name) { msg }
          raise BawWorkers::Exceptions::HarvesterEndpointError, msg
        end

        security_info
      end

      def get_access_result(project_id, site_id, uploader_id, security_info)
        access_result = @api_comm.check_uploader_project_access(project_id, site_id, uploader_id, security_info)

        unless access_result
          msg = "Could not get access to project_id #{project_id} for uploader_id #{uploader_id}."
          @logger.error(@class_name) { msg }
          raise BawWorkers::Exceptions::HarvesterEndpointError, msg
        end

        access_result
      end

      def get_audio_info_hash(file_info_hash, file_path)
        content_info_hash = @file_info_helper.audio_info(file_path)
        create_audio_info_hash(file_info_hash, content_info_hash)
      end

      def get_new_audio_recording(file_path, project_id, site_id, audio_info_hash, security_info)
        create_response = @api_comm.create_new_audio_recording(file_path, project_id, site_id, audio_info_hash, security_info)

        response_meta = create_response[:response]
        response_hash = create_response[:response_json]

        if response_hash.blank?

          msg = "Request to create audio recording from #{file_path} failed: Code #{response_meta.code}, Message: #{response_meta.message}, Body: #{response_meta.body}"

          # rename file if it is too short
          if response_meta.code == '422' &&
             response_meta.body.include?('duration_seconds') &&
             response_meta.body.include?('must be greater than or equal to')

            new_file_path = rename_short_file(file_path)
            msg += ", File renamed to #{new_file_path}."
          end

          @logger.error(@class_name) { msg }
          raise BawWorkers::Exceptions::HarvesterEndpointError, msg
        end

        response_hash
      end

      def create_audio_info_hash(file_info_hash, content_info_hash)
        info = {
          uploader_id: file_info_hash[:uploader_id].to_i,
          recorded_date: file_info_hash[:recorded_date],
          site_id: file_info_hash[:site_id].to_i,
          duration_seconds: content_info_hash[:duration_seconds].to_f.round(3),
          sample_rate_hertz: content_info_hash[:sample_rate_hertz].to_i,
          channels: content_info_hash[:channels].to_i,
          bit_rate_bps: content_info_hash[:bit_rate_bps].to_i,
          media_type: content_info_hash[:media_type].to_s,
          data_length_bytes: file_info_hash[:data_length_bytes].to_i,
          file_hash: content_info_hash[:file_hash].to_s,
          original_file_name: file_info_hash[:file_name].to_s
        }

        info[:notes] = {
          relative_path: file_info_hash[:file_rel_path].to_s
        }

        info[:notes] = info[:notes].merge(file_info_hash[:metadata]) if file_info_hash[:metadata]

        info
      end

      # Create hash for updating audio recording attributes.
      # @param [String] uuid
      # @param [String] file_hash
      # @param [String] status
      # @return [Hash]
      def create_update_hash(uuid, file_hash, status)
        {
          uuid: uuid,
          file_hash: file_hash,
          status: status
        }
      end

      # Copy file to be harvested to well-known locations
      # @param [String] file_path
      # @param [Hash] storage_file_opts
      # @return [Array<String>] storage target paths
      def copy_to_well_known_paths(file_path, storage_file_opts)
        storage_file_name = @original_audio.file_name_utc(storage_file_opts)
        storage_target_paths = @original_audio.possible_paths_file(storage_file_opts, storage_file_name)

        # copy to known machine-readable location
        @file_info_helper.copy_to_many(file_path, storage_target_paths)

        storage_target_paths
      end

      # Rename harvested file if copy was successful.
      # @param [String] file_path
      # @param [Array<String>] storage_target_paths
      # @return [Array<String>] storage target paths that exist and have the same file size as source
      def rename_harvested_file(file_path, storage_target_paths)
        # rename file once it is copied to all destinations
        source_size = File.size(file_path)

        check_target_paths = storage_target_paths.select { |file| File.exist?(file) && File.file?(file) && File.size(file) == source_size }

        if storage_target_paths.size == check_target_paths.size
          @logger.info(@class_name) do
            "Source file #{file_path} was copied successfully to all destinations, renaming source file."
          end

          renamed_source_file = file_path + '.completed'
          File.rename(file_path, renamed_source_file)

          if File.exist?(renamed_source_file)
            @logger.info(@class_name) {
              "Source file #{file_path} was successfully renamed to #{renamed_source_file}."
            }
          else
            @logger.warn(@class_name) {
              "Source file #{file_path} was not renamed."
            }
          end

        else
          msg = "Source file #{file_path} was not copied to all destinations #{storage_target_paths}."
          @logger.error(@class_name) { msg }
          raise BawWorkers::Exceptions::HarvesterIOError, msg
        end

        check_target_paths
      end

      # Rename non-harvested file if it is too short.
      # @param [String] file_path
      # @return [String] new file name
      def rename_short_file(file_path)
        rename_file(file_path, 'error_duration')
      end

      # Rename non-harvested file if it has no content.
      # @param [String] file_path
      # @return [String] new file name
      def rename_empty_file(file_path)
        rename_file(file_path, 'error_empty')
      end

      # Rename a file by appending a suffix as an extension.
      # @param [String] file_path
      # @return [String] new file name
      def rename_file(file_path, suffix)
        renamed_source_file = file_path + '.' + suffix
        File.rename(file_path, renamed_source_file)

        if File.exist?(renamed_source_file)
          @logger.info(@class_name) {
            "Invalid source file #{file_path} was successfully renamed to #{renamed_source_file}."
          }
        else
          @logger.warn(@class_name) {
            "Source file was not found, so not renamed #{file_path}."
          }
        end

        renamed_source_file
      end

      def create_relative_path(storage_file_opts)
        partial_path = @original_audio.partial_path(storage_file_opts)
        file_name = @original_audio.file_name_utc(storage_file_opts)
        File.join(partial_path, file_name)
      end
    end
  end
end
