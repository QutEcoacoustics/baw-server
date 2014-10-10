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

        # get auth token

        # Check uploader project access

        # construct file_info_hash for new audio recording request

        # send request to create new audio recording entry on website

        # catch any errors after audio is created so status can be updated

        # update audio recording status on website to uploading

        # copy to known machine-readable location with specified name

        # update audio recording status on website to ready (skipping to_check for now)
        # TODO: set to_check so file is checked independently

      end

    end
  end
end