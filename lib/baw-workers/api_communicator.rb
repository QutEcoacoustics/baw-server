module BawWorkers
  class ApiCommunicator

    include BawWorkers::Common

    # Create a new BawWorkers::ApiCommunicator.
    # @param [Object] logger
    # @param [Object] login_details
    # @param [Object] endpoints
    # @return [BawWorkers::ApiCommunicator]
    def initialize(logger, login_details, endpoints)
      @logger = logger
      @login_details = login_details
      @endpoints = endpoints
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
      else
        fail BawWorkers::Exceptions::HarvesterError, "Unrecognised HTTP method #{method}."
      end
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      request['Authorization'] = "Token token=\"#{auth_token}\"" if auth_token
      request.body = body.to_json unless body.blank?

      msg = "'#{description}': #{request.inspect}, URL: #{host}:#{port}#{endpoint}"
      @logger.debug(get_class_name) {
        "Sent request for #{msg}"
      }

      response = nil

      begin
        #res = Net::HTTP::Proxy('127.0.0.1', '8888').start(host, port) do |http|
        res = Net::HTTP.start(host, port) do |http|
          response = http.request(request)
        end
      rescue StandardError => e
        @logger.error(get_class_name) {
          "Request: #{msg}, Error: #{e}\nBacktrace: #{e.backtrace.join("\n")}"
        }
        raise e
      end

      @logger.debug(get_class_name) {
        "Received response for '#{description}': #{response.inspect}, URL: #{host}:#{port}#{endpoint}, Body: #{response.body}"
      }

      response
    end

    # Request an auth token (using an existing token if available).
    # @param [string] auth_token
    # @return [string] The auth_token.
    def request_login(auth_token = nil)
      login_response = send_request('Login request', :post, host, port, endpoint_login, auth_token, {email: user, password: password})
      if login_response.code == '200' && !login_response.body.blank?
        @logger.debug(get_class_name) {
          "Successfully got auth_token: #{login_response.body}."
        }
        json_resp = JSON.parse(login_response.body)
        json_resp['auth_token']
      else
        @logger.error(get_class_name) {
          "Problem getting auth_token: #{login_response}."
        }
        nil
      end
    end

    # Update audio recording metadata
    def update_audio_recording_details(description, file_to_process, audio_recording_id, update_hash, auth_token)
      endpoint = endpoint_audio_recording.gsub(':id', audio_recording_id.to_s)
      response = send_request("Update audio recording metadata - #{description}", :put, host, port, endpoint, auth_token, update_hash)
      if response.code == '200' || response.code == '204'
        @logger.debug(get_class_name) {
          "Audio recording metadata update '#{description}' succeeded '#{file_to_process}' - id: #{audio_recording_id} hash: '#{update_hash}'"
        }
        true
      else
        @logger.error(get_class_name) {
          "Audio recording metadata update '#{description}' failed with code #{response.code} '#{file_to_process}' - id: #{audio_recording_id} hash: '#{update_hash}' response: #{response.inspect}"
        }
        false
      end
    end

    # Check that uploader_id has access to project_id.
    # @param [string] project_id
    # @param [string] site_id
    # @param [string] uploader_id
    # @param [string] auth_token
    # @return [bool]
    def check_uploader_project_access(project_id, site_id, uploader_id, auth_token)
      if auth_token
        @logger.debug(get_class_name) {
          "Checking uploader id #{uploader_id} access to project id #{project_id}."
        }

        if uploader_check_success?(project_id, site_id, uploader_id, auth_token)
          @logger.info(get_class_name) {
            "Uploader with id #{uploader_id} has access to project id #{project_id}."
          }
          true
        else
          @logger.error(get_class_name) {
            "Uploader id #{uploader_id} does not have required permissions for project id #{project_id}."
          }
          false
        end
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

    def create_audio_info_hash(file_info_hash, content_info_hash, file_hash_string)
      {
          bit_rate_bps: content_info_hash[:bit_rate_bps].to_i,
          channels: content_info_hash[:channels].to_i,
          data_length_bytes: file_info_hash[:data_length_bytes].to_i,
          duration_seconds: content_info_hash[:duration_seconds].to_f.round(4),
          media_type: content_info_hash[:media_type].to_s,
          recorded_date: file_info_hash[:recorded_date],
          sample_rate_hertz: content_info_hash[:sample_rate].to_i,
          uploader_id: file_info_hash[:uploader_id].to_i,
          file_hash: file_hash_string,
          original_file_name: file_info_hash[:file_name].to_s,
          site_id: file_info_hash[:site_id].to_i
      }
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
      response = send_request('Create audio recording', :post, host, port, endpoint, auth_token, audio_info_hash)
      if response.code == '201'
        response_json = JSON.parse(response.body)
        @logger.info(get_class_name) {
          "Created new audio recording with id #{response_json['id']}: #{file_to_process}."
        }
        {response: response, response_json: response_json}
      else
        {response: response, response_json: nil}
      end
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
      if response.code == '200' || response.code == '204'
        @logger.debug(get_class_name) {
          "Audio recording status update '#{description}' succeeded '#{file_to_process}' - id: #{audio_recording_id} hash: '#{update_hash}'"
        }
        true
      else
        @logger.error(get_class_name) {
          "Audio recording status update '#{description}' failed with code #{response.code} '#{file_to_process}' - id: #{audio_recording_id} hash: '#{update_hash}'"
        }
        false
      end
    end

  end
end