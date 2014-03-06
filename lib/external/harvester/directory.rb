module Harvester
  class Directory

    attr_reader :harvest_file, :harvest_config, :directory

    # @param [string] harvest_file
    # @param [Harvester::Shared] harvester_shared
    def initialize(harvest_file, harvester_shared)
      @harvest_file = harvest_file
      @directory = File.dirname(harvest_file)
      @shared = harvester_shared

      @harvest_config = @shared.load_config_file(@harvest_file)
    end

    def check_uploader_id
      request_description = 'Check uploader id'
      uploader_id = @shared.settings['uploader_id']
      project_id = @harvest_config['project_id']
      site_id = @harvest_config['site_id']

      endpoint = @shared.settings['endpoint_check_uploader']
        .gsub!(':project_id', project_id.to_s)
        .gsub!(':site_id', site_id.to_s)
        .gsub!(':uploader_id', uploader_id.to_s)

        check_uploader_response = @shared.send_request(request_description, :get, endpoint)
        if check_uploader_response.code.to_s == '204'
          @shared.log_with_puts Logger::INFO, "Uploader with id #{uploader_id} has project access."
          true
        else
          @shared.log_with_puts Logger::ERROR, "Uploader with id #{@config_file_object['uploader_id']} has project access."
          false
          raise Exceptions::HarvesterConfigurationError, "Check your #{@settings.config_file_name} file: Uploader ID #{@config_file_object['uploader_id']} does not have required permissions for Project ID #{@config_file_object['project_id']}"
        end
    end
  end
end