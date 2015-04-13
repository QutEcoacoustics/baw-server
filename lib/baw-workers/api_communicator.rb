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

    def host; @login_details['host']; end
    def port; @login_details['port']; end
    def user; @login_details['user']; end
    def password; @login_details['password']; end

    def endpoint_login; @endpoints['login']; end
    def endpoint_audio_recording; @endpoints['audio_recording']; end
    def endpoint_audio_recording_create; @endpoints['audio_recording_create']; end
    def endpoint_audio_recording_uploader; @endpoints['audio_recording_uploader']; end
    def endpoint_audio_recording_update_status; @endpoints['audio_recording_update_status']; end

    # Send HTTP request.
    # @param [string] description
    # @param [Symbol] method
    # @param [string] endpoint
    # @param [Hash] body
    # @return [Net::HTTP::Response] The response.
    def send_request(description, method, host, port, endpoint, auth_token, body = nil)

      if method == :get
        request = Net::HTTP::Get.new(endpoint)
      elsif method == :put
        request = Net::HTTP::Put.new(endpoint)
      elsif method == :post
        request = Net::HTTP::Post.new(endpoint)
      elsif method == :head
        request = Net::HTTP::Head.new(endpoint)
      elsif method == :patch
        request = Net::HTTP::Patch.new(endpoint)
      else
        fail BawWorkers::Exceptions::HarvesterError, "Unrecognised HTTP method #{method}."
      end

      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      request['Authorization'] = "Token token=\"#{auth_token}\"" if auth_token
      request.body = body.to_json unless body.blank?

      msg = "'#{description}'. Url: #{host}:#{port}#{endpoint}"

      @logger.debug(@class_name) {
        "[HTTP] Sent request for #{msg}, Request: #{request.inspect}"
      }

      response = nil

      begin
        #res = Net::HTTP::Proxy('127.0.0.1', '8888').start(host, port) do |http|
        res = Net::HTTP.start(host, port) do |http|
          response = http.request(request)
        end
      rescue StandardError => e
        @logger.error(@class_name) {
          "[HTTP] Request for #{msg}, Request: #{request.inspect}, Error: #{e}\nBacktrace: #{e.backtrace.join("\n")}"
        }
        fail e
      end

      @logger.info(@class_name) {
        response_msg = @logger.debug? ? "Response: #{response.inspect}" : "Code: #{response.code}, Body: #{response.body}"
        "[HTTP] Received response for #{msg}, #{response_msg}"
      }

      response
    end

    # Request an auth token (using an existing token if available).
    # @param [string] auth_token
    # @return [string] The auth_token.
    def request_login(auth_token = nil)
      login_response = send_request('Login request', :post, host, port, endpoint_login, auth_token, {email: user, password: password})
      if login_response.code == '200' && !login_response.body.blank?
        @logger.info(@class_name) {
          '[HTTP] Got auth token in response body.'
        }
        json_resp = JSON.parse(login_response.body)
        json_resp['data']['auth_token']
      else
        @logger.error(@class_name) {
          '[HTTP] Problem requesting auth token.'
        }
        nil
      end
    end

    # Update audio recording metadata
    def update_audio_recording_details(description, file_to_process, audio_recording_id, update_hash, auth_token)
      endpoint = endpoint_audio_recording.gsub(':id', audio_recording_id.to_s)
      response = send_request("Update audio recording metadata - #{description}", :put, host, port, endpoint, auth_token, update_hash)
      msg = "Code #{response.code}, Id: #{audio_recording_id}, Hash: '#{update_hash}', File: '#{file_to_process}'"

      if response.code == '200' || response.code == '204'
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
    # @param [string] auth_token
    # @return [Boolean]
    def check_uploader_project_access(project_id, site_id, uploader_id, auth_token)
      if auth_token
        if uploader_check_success?(project_id, site_id, uploader_id, auth_token)
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
    # @param [String] auth_token
    # @return [Boolean] true if uploader_id has access to project_id
    def uploader_check_success?(project_id, site_id, uploader_id, auth_token)
      endpoint = endpoint_audio_recording_uploader
      .gsub(':project_id', project_id.to_s)
      .gsub(':site_id', site_id.to_s)
      .gsub(':uploader_id', uploader_id.to_s)

      check_uploader_response = send_request('Check uploader id', :get, host, port, endpoint, auth_token)
      check_uploader_response.code.to_i == 204
    end

    # Create a new audio recording.
    # @param [String] file_to_process
    # @param [Integer] project_id
    # @param [Integer] site_id
    # @param [Hash] audio_info_hash
    # @param [String] auth_token
    # @return [Hash] response and response json
    def create_new_audio_recording(file_to_process, project_id, site_id, audio_info_hash, auth_token)
      endpoint = endpoint_audio_recording_create
      .gsub(':project_id', project_id.to_s)
      .gsub(':site_id', site_id.to_s)

      msg = "Project: #{project_id}, Site: #{site_id}, File: #{file_to_process}, Params: #{audio_info_hash}"

      response = send_request('Create audio recording', :post, host, port, endpoint, auth_token, audio_info_hash)
      if response.code == '201'
        response_json = JSON.parse(response.body)
        @logger.info(@class_name) {
          "[HTTP] Created new audio recording. Id: #{response_json['id']}, #{msg}"
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
    # @param [String] auth_token
    # @return [Boolean] successful?
    def update_audio_recording_status(description, file_to_process, audio_recording_id, update_hash, auth_token)
      endpoint = endpoint_audio_recording_update_status.gsub(':id', audio_recording_id.to_s)
      response = send_request("Update audio recording status - #{description}", :put, host, port, endpoint, auth_token, update_hash)
      msg = "'#{description}'. Code #{response.code}, File: '#{file_to_process}', Id: #{audio_recording_id}, Hash: '#{update_hash}'"
      if response.code == '200' || response.code == '204'
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