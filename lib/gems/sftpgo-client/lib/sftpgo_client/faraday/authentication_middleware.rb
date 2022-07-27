# frozen_string_literal: true

module SftpgoClient
  # Raised when we tried to authenticate and failed
  class AuthenticationFailure < Faraday::ClientError; end

  # Raised when we attempted a normal request and failed
  class NeedsAuthenticationFailure < Faraday::ClientError; end

  # Faraday middleware that allows for on the fly authentication of requests.
  # When a request fails (a status of 401 is returned), the middleware
  # will attempt to either re-authenticate (username and password) or refresh
  # the oauth access token (if a refresh token is present).
  class AuthenticationMiddleware < Faraday::Middleware
    # @return [ApiClient]
    attr_reader :client

    # @return [::SemanticLogger::Logger]
    attr_reader :logger

    def initialize(app, client, logger)
      super(app)

      raise ArgumentError, 'client must be and ApiClient' unless client.is_a?(ApiClient)

      @client = client
      @logger = logger
    end

    # Rescue from 401's, authenticate then raise the error again so the client
    # can reissue the request.
    def call(env)
      authenticate! if authenticate_before?(env)

      request_body = env[:body]
      attempts = 0
      result = nil
      begin
        attempts += 1
        # after failure env[:body] is set to the response body
        # reset it to original body
        env[:body] = request_body
        # also reset our internal failure tracking state
        env[:failure] = nil

        add_auth_header(env)

        result = @app.call(env).on_complete { |response_env|
          authenticate_on_fail!(response_env)
        }
      rescue NeedsAuthenticationFailure => e
        logger.debug('Authenticating again after failure against SFTPGO API', e.message)
        authenticate!

        retry if attempts < 2
      end

      result
    end

    def authenticate_before?(env)
      return false if authentication_request?(env)

      client.token.nil?
    end

    def authenticate_on_fail!(env)
      return if authentication_request?(env)

      return if env[:status] == 200
      return unless env[:status] == 401

      raise NeedsAuthenticationFailure.new("Needs authentication: #{env[:status]}, #{env.body}", env[:response])
    end

    def authentication_request?(env)
      env[:url].path.ends_with?(TokenService::TOKEN_PATH)
    end

    # Performs the authentication
    def authenticate!
      client.token = nil
      logger.debug('Attempting to authenticate against SFTPGO API', token: client.token)
      result = client.get_token
      unless result.success?
        logger.error('Failed to authenticate')
        raise AuthenticationFailure, result.failure
      end

      client.token = result.value!

      logger.debug('Authentication successful', token: client.token)
    end

    def add_auth_header(env)
      value = authentication_request?(env) ? basic_auth : token_auth

      env.request_headers[Faraday::Request::Authorization::KEY] = value

      logger.debug('Added auth header', authorization: value)
    end

    def token_auth
      value = client&.token&.access_token
      return if value.blank?

      "Bearer #{value}"
    end

    def basic_auth
      login = client.username
      password = client.password
      value = Base64.encode64("#{login}:#{password}")
      value.delete!("\n")
      "Basic #{value}"
    end
  end
end
