module BawWorkers
  module Harvest
    # Get a list of files to be harvested.
    class SingleFile

      # include common methods
      include BawWorkers::Common

      # Create a new BawWorkers::Harvest::SingleFile.
      # @param [Logger] logger
      # @param [BawWorkers::FileInfo] file_info_helper
      # @param [BawWorkers::ApiCommunicator] api_comm
      # @return [BawWorkers::Harvest::SingleFile]
      def initialize(logger, file_info_helper, api_comm)
        @logger = logger
        @file_info_helper = file_info_helper
        @api_comm = api_comm
      end

      def run(file_info_hash)
        project_id = file_info_hash[:project_id]
        site_id = file_info_hash[:site_id]
        uploader_id = file_info_hash[:uploader_id]
        file_path = file_info_hash[:file_path]


        # get auth token
        # -----------------------------
        auth_token = @api_comm.request_login
        fail BawWorkers::Exceptions::HarvesterEndpointError, 'Could not get valid auth_token' if auth_token.blank?

        # Check uploader project access
        # -----------------------------
        access_result = @api_comm.check_uploader_project_access(
            project_id,
            site_id,
            uploader_id,
            auth_token)

        unless access_result
          msg = "Could not get access to project_id #{project_id} for uploader_id #{uploader_id}."
          @logger.error(get_class_name) { msg }
          fail BawWorkers::Exceptions::HarvesterEndpointError, msg
        end

        # construct file_info_hash for new audio recording request
        # -----------------------------
        content_info_hash = @file_info_helper.audio_info(file_path)
        audio_info_hash = create_audio_info_hash(file_info_hash, content_info_hash)

        file_hash = audio_info_hash[:file_hash]

        # send request to create new audio recording entry on website
        # -----------------------------
        create_response = @api_comm.create_new_audio_recording(
            file_path,
            project_id,
            site_id,
            audio_info_hash,
            auth_token
        )

        response_meta = create_response[:response]
        response_hash = create_response[:response_json]

        if response_hash.blank?
          msg = "Request to create audio recording from #{file_path} failed: Code #{response_meta.code}, Message: #{response_meta.message}, Body: #{response_meta.body}"
          @logger.error(get_class_name) { msg }
          fail BawWorkers::Exceptions::HarvesterEndpointError, msg
        end

        audio_recording_id = response_hash['id']
        audio_recording_uuid = response_hash['uuid']

        # catch any errors after audio is created so status can be updated
        # -----------------------------
        begin

          # update audio recording status on website to uploading
          # description, file_to_process, audio_recording_id, update_hash, auth_token
          @api_comm.update_audio_recording_status(
              'record pending file move',
              file_path,
              audio_recording_id,
              create_update_hash(audio_recording_uuid, file_hash, :uploading),
              auth_token)

          # @file_info_helper.copy_to_many(
          #     file_info_hash[:file_path],
          #     create_response[:response_json],
          #     file_info_hash
          # )

          # TODO: set to_check so file has is checked independently
          # update audio recording status on website to ready (skipping to_check for now)
          @api_comm.update_audio_recording_status(
              'record completed file move',
              file_path,
              audio_recording_id,
              create_update_hash(audio_recording_uuid, file_hash, :ready),
              auth_token)
        rescue Exception => e
          msg =  "Error after audio recording created on website, status set to aborted. Exception: #{e}"
          @logger.error(get_class_name) { msg }
          @api_comm.update_audio_recording_status(
              'record error in harvesting',
              file_path,
              audio_recording_id,
              create_update_hash(audio_recording_uuid, file_hash, :aborted),
              auth_token)
          raise e
        end

        # update audio recording status on website to uploading

        # copy to known machine-readable location with specified name

        # update audio recording status on website to ready (skipping to_check for now)
        # TODO: set to_check so file is checked independently
        a = 1
      end

      private

      def create_audio_info_hash(file_info_hash, content_info_hash)
        {}.merge(file_info_hash).merge(content_info_hash)

        # {
        #     bit_rate_bps: content_info_hash[:bit_rate_bps].to_i,
        #     channels: content_info_hash[:channels].to_i,
        #     data_length_bytes: file_info_hash[:data_length_bytes].to_i,
        #     duration_seconds: content_info_hash[:duration_seconds].to_f.round(4),
        #     media_type: content_info_hash[:media_type].to_s,
        #     recorded_date: file_info_hash[:recorded_date],
        #     sample_rate_hertz: content_info_hash[:sample_rate].to_i,
        #     uploader_id: file_info_hash[:uploader_id].to_i,
        #     file_hash: content_info_hash[:file_hash],
        #     original_file_name: file_info_hash[:file_name].to_s,
        #     site_id: file_info_hash[:site_id].to_i
        # }
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

    end
  end
end