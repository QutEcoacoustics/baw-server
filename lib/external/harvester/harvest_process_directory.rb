module Harvester
  class ProcessDirectory

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

    def start_harvesting_dir

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

    # get the list of files in a directory, excluding the config file.
    def file_list(full_directory_path)
      path = File.join(full_directory_path, '*')
      list_of_files = Dir[path].reject { |fn| File.directory?(fn) || File.basename(fn) == @settings.config_file_name || File.basename(fn) == File.basename(@process_log_file) || File.basename(fn) == File.basename(@error_log_file) || File.basename(fn) == File.basename(@listen_log_file) }
      if list_of_files.empty?
        log Logger::WARN, "Could not find any audio files in #{full_directory_path}"
      else
        log Logger::INFO, "Found #{list_of_files.size} files in #{full_directory_path}"
        list_of_files
      end
    end

    def check_config_file(full_directory_path)

      full_file_path = File.join(full_directory_path, @settings.config_file_name)

      # if the config file does not exist, raise exception
      if File.exists?(full_file_path)
        # load the config file
        @config_file_object = YAML.load_file(full_file_path)

        # get project_id and site_id from config file, raise exception if they are not defined
        project_id = @config_file_object['project_id']
        site_id = @config_file_object['site_id']

        if project_id.nil? || !project_id.is_a?(Fixnum)
          false
          raise Exceptions::HarvesterConfigurationError, 'Config file must contain a project_id'
        elsif site_id.nil? || !site_id.is_a?(Fixnum)
          false
          raise Exceptions::HarvesterConfigurationError, 'Config file must contain a site_id'
        end

        true
      else
        # load the config file in the same dir, raise exception if it doesn't exits
        false
        raise Exceptions::HarvesterConfigFileNotFound.new("Config file #{full_file_path} does not exist.")
      end
    end

  end
end