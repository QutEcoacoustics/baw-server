module BawWorkers
  class ApiCommunicator

    def initialize(logger)
      @logger = logger
    end

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
        fail ArgumentError, "Unrecognised HTTP method #{method}."
      end
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      request['Authorization'] = "Token token=\"#{auth_token}\"" if auth_token
      request.body = body.to_json unless body.blank?

      msg = "'#{description}': #{request.inspect}, URL: #{host}:#{port}#{endpoint}"
      @logger.log Logger::DEBUG, "Sent request for #{msg}, Body: #{request.body}"

      response = nil

      begin
        #res = Net::HTTP::Proxy('127.0.0.1', '8888').start(host, port) do |http|
        res = Net::HTTP.start(host, port) do |http|
          response = http.request(request)
        end
      rescue StandardError => e
        @logger.log(Logger::ERROR, "Request: #{msg}, Error: #{e}\nBacktrace: #{e.backtrace.join("\n")}")
        #@logger.log(Logger::ERROR, "Request: #{msg}, Error: #{e}")
        raise e
      end

      @logger.log Logger::DEBUG, "Received response for '#{description}': #{response.inspect}, URL: #{host}:#{port}#{endpoint}, Body: #{response.body}"

      response
    end

    # request an auth token
    # @param [string] email
    # @param [string] password
    # @param [string] endpoint_login
    # @return [string] The auth_token.
    def request_login(email, password, host, port, auth_token, endpoint_login)
      login_response = send_request('Login request', :post, host, port, endpoint_login, auth_token, {email: email, password: password})
      if login_response.code == '200' && !login_response.body.blank?
        @logger.log Logger::DEBUG, "Successfully got auth_token: #{login_response.body}."
        json_resp = JSON.parse(login_response.body)
        json_resp['auth_token']
      else
        @logger.log Logger::ERROR, "Problem getting auth_token: #{login_response}."
        nil
      end
    end

    # Update audio recording metadata
    def update_audio_recording_details(description, file_to_process, audio_recording_id, update_hash, host, port, auth_token, endpoint_update_all)
      endpoint = endpoint_update_all.gsub(':id', audio_recording_id.to_s)
      response = send_request("Update audio recording metadata - #{description}", :put, host, port, endpoint, auth_token, update_hash)
      if response.code == '200' || response.code == '204'
        @logger.log Logger::DEBUG, "Audio recording metadata update '#{description}' succeeded '#{file_to_process}' - id: #{audio_recording_id} hash: '#{update_hash}'"
        true
      else
        @logger.log Logger::ERROR, "Audio recording metadata update '#{description}' failed with code #{response.code} '#{file_to_process}' - id: #{audio_recording_id} hash: '#{update_hash}'"
        false
      end
    end

  end
end