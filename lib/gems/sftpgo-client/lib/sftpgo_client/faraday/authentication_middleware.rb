# frozen_string_literal: true

module SftpgoClient
  # Raised when we tried to authenticate and failed
  class AuthenticationFailure < Faraday::ClientError; end

  # Faraday middleware that allows for on the fly authentication of requests.
  # When a request fails (a status of 401 is returned), the middleware
  # will attempt to either re-authenticate (username and password) or refresh
  # the oauth access token (if a refresh token is present).
  class AuthenticationMiddleware < Faraday::Middleware
    # @return [ApiClient]
    attr_reader :client

    def initialize(app, client, logger)
      super(app)

      raise ArgumentError, 'client must be and ApiClient' unless client.is_a?(ApiClient)

      @client = client
      @logger = logger
    end

    # Rescue from 401's, authenticate then raise the error again so the client
    # can reissue the request.
    def call(env)
      authenticate!(env) if authenticate_before?(env)

      @app.call(env).on_complete do |response_env|
        if authenticate_on_fail?(response_env)
          authenticate!(env)

          # now try again
          @app.call(env) do |new_response|
            next new_response
          end
        end

        response_env
      end
    end

    def authenticate_before?(env)
      return false if authentication_request?(env)

      client.token.nil?
    end

    def authenticate_on_fail?(env)
      return false if authentication_request?(env)

      env[:status] == 401
    end

    def authentication_request?(env)
      env[:url].path.ends_with?(TokenService::TOKEN_PATH)
    end

    # Performs the authentication and updates the original request with new headers
    def authenticate!(env)
      @logger.debug('Attempting to authenticate against SFTPGO API', log_header)
      result = client.get_token
      unless result.success?
        @logger.error('Failed to authenticate')
        raise AuthenticationFailure, result.failure
      end

      client.token = result.value!
      client.connection.authorization('Bearer', client.token.access_token)
      @logger.debug('Authentication successful', log_header)

      # ensure old request has new header
      update_request(env)
    end

    def update_request(env)
      env.request_headers[Faraday::Request::Authorization::KEY] =
        client.connection.headers[Faraday::Request::Authorization::KEY]
    end

    def log_header
      {
        'Authorization' => client.connection.headers[Faraday::Request::Authorization::KEY] #,
        #username: client.instance_variable_get(:@username),
        #password: client.instance_variable_get(:@password)
      }
    end
  end
end
