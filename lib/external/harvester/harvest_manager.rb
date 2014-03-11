module Harvester
  class Manager

    attr_reader :shared

    # @param [string] global_config_file
    def initialize(global_config_file)
      raise Exceptions::HarvesterConfigFileNotFound, "Configuration file not found: #{global_config_file}" unless !global_config_file.nil? && File.exists?(global_config_file)
      @shared = Harvester::Shared.new(global_config_file)
    end

    # request an auth token
    # @return [string]
    def request_login
      login_description = 'Login request'
      login_email = @shared.settings['login_email']
      login_password = @shared.settings['login_password']
      endpoint = @shared.settings['endpoint_login']

      login_response = @shared.send_request(login_description, :post, endpoint, {email: login_email, password: login_password})

      if login_response.code == '200' && !login_response.body.blank?
        log_with_puts Logger::INFO, 'Successfully logged in.'
        json_resp = JSON.parse(login_response.body)
        @shared.auth_token = json_resp['auth_token']
        @shared.auth_token
      else
        msg = 'Failed to log in and obtain auth_token'
        log_with_puts Logger::ERROR, msg
        raise Exceptions::HarvesterConfigurationError, msg
      end
    end


    def run

    end
  end
end