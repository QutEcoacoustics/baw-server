module Harvester
  class Directory

    attr_reader :harvest_directory, :harvest_dir_file, :harvest_dir_config

    # Initialize Harvester::Directory with a harvest file and harvest shared class.
    # @param [string] harvest_file
    # @param [Harvester::Shared] harvester_shared
    def initialize(harvest_file, harvester_shared)
      @shared = harvester_shared
      @harvest_dir_file = harvest_file
      @harvest_directory = File.dirname(@harvest_dir_file)
      @harvest_dir_config = @shared.load_config_file(@harvest_dir_file)
    end

    # Ask server to check uploader id.
    # @param [int] project_id
    # @param [int] site_id
    # @param [int] uploader_id
    # @return [boolean] true if uploader with id has write access to project id
    def check_uploader_id(project_id, site_id, uploader_id)
      request_description = 'Check uploader id'

      endpoint = @shared.settings['endpoint_check_uploader']
      .gsub!(':project_id', project_id.to_s)
      .gsub!(':site_id', site_id.to_s)
      .gsub!(':uploader_id', uploader_id.to_s)

      check_uploader_response = @shared.send_request(request_description, :get, endpoint)
      result_success = check_uploader_response.code.to_s == '204'

      msg = "Uploader with id #{uploader_id} #{result_success ? 'has' : 'does not have'} write access to project with id #{project_id} (using site id #{site_id})."

      if check_uploader_response.code.to_s == '204'
        @shared.log_with_puts Logger::INFO, msg
        true
      else
        hint_msg = "Check your directory settings file (#@harvest_dir_file): uploader with id #{uploader_id} does not have required permissions for project with id #{project_id}."
        @shared.log_with_puts Logger::ERROR, hint_msg +' '+msg
        false
      end
    end
  end
end