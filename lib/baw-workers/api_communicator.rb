module BawWorkers
  class ApiCommunicator

    attr_accessor :logger

    # Create a new BawWorkers::ApiCommunicator.
    # @param [Object] logger
    # @param [Object] login_details
    # @param [Object] endpoints
    # @return [BawWorkers::ApiCommunicator]
    def initialize(logger, login_details, endpoints)
      @logger = logger
      @login_details = login_details
      @endpoints = endpoints

      @class_name = self.class.name
    end

    def host;
      @login_details['host'];
    end

    def port;
      @login_details['port'];
    end

    def user;
      @login_details['user'];
    end

    def password;
      @login_details['password'];
    end

    def endpoint_login;
      @endpoints['login'];
    end

    def endpoint_audio_recording;
      @endpoints['audio_recording'];
    end

    def endpoint_audio_recording_create;
      @endpoints['audio_recording_create'];
    end

    def endpoint_audio_recording_uploader;
      @endpoints['audio_recording_uploader'];
    end

    def endpoint_audio_recording_update_status;
      @endpoints['audio_recording_update_status'];
    end

    # Send HTTP request.
    # @param [string] description
    # @param [Symbol] method
    # @param [String] host
    # @param [Integer] port
    # @param [string] endpoint
    # @param [Hash] security_info
    # @param [Hash] body
    # @return [Net::HTTP::Response] The response.
    def send_request(description, method, host, port, endpoint, security_info = {auth_token: nil, cookies: nil}, body = nil)

      case method
        when :get
          request = Net::HTTP::Get.new(endpoint)
        when :put
          request = Net::HTTP::Put.new(endpoint)
        when :post
          request = Net::HTTP::Post.new(endpoint)
        when :head
          request = Net::HTTP::Head.new(endpoint)
        when :patch
          request = Net::HTTP::Patch.new(endpoint)
        else
          fail ArgumentError, "Unrecognised HTTP method #{method}."
      end

      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      request['Authorization'] = "Token token=\"#{security_info[:auth_token]}\"" if security_info && security_info.include?(:auth_token) && !security_info[:auth_token].nil?

      # extract XSRF-TOKEN from cookie, and put into X-XSRF-TOKEN header
      if security_info && security_info.include?(:cookies) && !security_info[:cookies].nil?

        # include cookies if any were set
        request['Cookie'] = security_info[:cookies]

        cookie_strings = security_info[:cookies].split('; ')
        xsrf_cookie = nil
        key_string = 'XSRF-TOKEN='
        cookie_strings.each do |cookie_string|
          if cookie_string.start_with?(key_string)
            xsrf_cookie = cookie_string[key_string.size..-1]
            break
          end
        end

        unless xsrf_cookie.nil?
          url_decoded = URI.decode_www_form_component(xsrf_cookie)
          request['X-XSRF-TOKEN'] = url_decoded
        end

      end

      request.body = body.to_json unless body.blank?

      msg = "#{method} '#{description}'. Url: #{host}:#{port}#{endpoint}"

      response = nil

      begin
        #res = Net::HTTP::Proxy('127.0.0.1', '8888').start(host, port) do |http|
        res = Net::HTTP.start(host, port) do |http|
          response = http.request(request)

          @logger.debug(@class_name) {
            "[HTTP] Sent request for #{msg}, Body: #{request.body}, Headers: #{request.to_hash}"
          }

        end
      rescue StandardError => e
        @logger.error(@class_name) {
          "[HTTP] Request for #{msg}, Body: #{request.body}, Headers: #{request.to_hash}, Error: #{e}\nBacktrace: #{e.backtrace.join("\n")}"
        }
        fail e
      end

      @logger.info(@class_name) {
        "[HTTP] Received response for #{msg}, Code: #{response.code}, Body: #{response.body}, Headers: #{response.to_hash}"
      }

      response
    end

    # Request an auth token (using an existing token if available).
    # @return [Hash]
    def request_login
      login_response = send_request('Login request', :post, host, port, endpoint_login, nil, {email: user, password: password})

      # get cookies
      # from http://stackoverflow.com/a/9320190/31567
      all_cookies = login_response.get_fields('set-cookie')

      cookies = nil

      if all_cookies && all_cookies.respond_to?(:each)
        cookies_array = []
        all_cookies.each { |cookie|
          cookies_array.push(cookie.split('; ')[0])
        }
        cookies = cookies_array.join('; ')
      end

      if login_response.code.to_i == 200 && !login_response.body.blank?
        @logger.info(@class_name) {
          '[HTTP] Got auth token in response body.'
        }
        json_resp = JSON.parse(login_response.body)

        {
            auth_token: json_resp['data']['auth_token'],
            cookies: cookies
        }
      else
        @logger.error(@class_name) {
          '[HTTP] Problem requesting auth token.'
        }

        {
            auth_token: nil,
            cookies: cookies
        }
      end
    end

    # Update audio recording metadata
    def update_audio_recording_details(description, file_to_process, audio_recording_id, update_hash, security_info)
      endpoint = endpoint_audio_recording.gsub(':id', audio_recording_id.to_s)
      response = send_request("Update audio recording metadata - #{description}", :put, host, port, endpoint, security_info, update_hash)
      msg = "Code #{response.code}, Id: #{audio_recording_id}, Hash: '#{update_hash}', File: '#{file_to_process}'"

      if response.code.to_i == 200 || response.code.to_i == 204
        @logger.info(@class_name) {
          "[HTTP] Audio recording metadata update '#{description}' succeeded. #{msg}"
        }
        true
      else
        @logger.error(@class_name) {
          "[HTTP] Audio recording metadata update '#{description}' failed. #{msg}"
        }
        false
      end
    end

    # Check that uploader_id has access to project_id.
    # @param [string] project_id
    # @param [string] site_id
    # @param [string] uploader_id
    # @param [Hash] security_info
    # @return [Boolean]
    def check_uploader_project_access(project_id, site_id, uploader_id, security_info)
      if security_info
        if uploader_check_success?(project_id, site_id, uploader_id, security_info)
          @logger.info(@class_name) {
            "[HTTP] Uploader with id #{uploader_id} has access to project id #{project_id}."
          }
          true
        else
          @logger.error(@class_name) {
            "[HTTP] Uploader id #{uploader_id} does not have required permissions for project id #{project_id}."
          }
          false
        end
      else
        @logger.error(@class_name) {
          "[HTTP] No auth token given so cannot check uploader with id #{uploader_id}  access to project id #{project_id}."
        }
        false
      end
    end

    # Send request to check project access.
    # @param [string] project_id
    # @param [string] site_id
    # @param [string] uploader_id
    # @param [Hash] security_info
    # @return [Boolean] true if uploader_id has access to project_id
    def uploader_check_success?(project_id, site_id, uploader_id, security_info)
      endpoint = endpoint_audio_recording_uploader
                     .gsub(':project_id', project_id.to_s)
                     .gsub(':site_id', site_id.to_s)
                     .gsub(':uploader_id', uploader_id.to_s)

      check_uploader_response = send_request('Check uploader id', :get, host, port, endpoint, security_info)
      check_uploader_response.code.to_i == 204
    end

    # Create a new audio recording.
    # @param [String] file_to_process
    # @param [Integer] project_id
    # @param [Integer] site_id
    # @param [Hash] audio_info_hash
    # @param [Hash] security_info
    # @return [Hash] response and response json
    def create_new_audio_recording(file_to_process, project_id, site_id, audio_info_hash, security_info)
      endpoint = endpoint_audio_recording_create
                     .gsub(':project_id', project_id.to_s)
                     .gsub(':site_id', site_id.to_s)

      msg = "Project: #{project_id}, Site: #{site_id}, File: #{file_to_process}, Params: #{audio_info_hash}"

      response = send_request('Create audio recording', :post, host, port, endpoint, security_info, audio_info_hash)
      if response.code.to_i == 201
        response_json = JSON.parse(response.body)
        @logger.info(@class_name) {
          "[HTTP] Created new audio recording. Id: #{response_json['data']['id']}, #{msg}"
        }
        {response: response, response_json: response_json}
      else
        @logger.error(@class_name) {
          "[HTTP] Problem creating new audio recording. #{msg}"
        }
        {response: response, response_json: nil}
      end
    end

    # Update audio recording status.
    # @param [String] description
    # @param [String] file_to_process
    # @param [Integer] audio_recording_id
    # @param [Hash] update_hash
    # @param [Hash] security_info
    # @return [Boolean] successful?
    def update_audio_recording_status(description, file_to_process, audio_recording_id, update_hash, security_info)
      endpoint = endpoint_audio_recording_update_status.gsub(':id', audio_recording_id.to_s)
      response = send_request("Update audio recording status - #{description}", :put, host, port, endpoint, security_info, update_hash)
      msg = "'#{description}'. Code #{response.code}, File: '#{file_to_process}', Id: #{audio_recording_id}, Hash: '#{update_hash}'"
      if response.code.to_i == 200 || response.code.to_i == 204
        @logger.info(@class_name) {
          "[HTTP] Audio recording status updated for #{msg}"
        }
        true
      else
        @logger.error(@class_name) {
          "[HTTP] Problem updating audio recording status for #{msg}"
        }
        false
      end
    end

  end
end