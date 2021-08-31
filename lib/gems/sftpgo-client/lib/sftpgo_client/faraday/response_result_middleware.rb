# frozen_string_literal: true

require_relative '../models/api_response'

module SftpgoClient
  # Adds an exception to env for failed responses.
  # Up to the caller as to whether or not the failure is raised.
  class ResponseResultMiddleware
    # rubocop:disable Naming/ConstantName
    ClientErrorStatuses = (400...500)
    ServerErrorStatuses = (500...600)
    # rubocop:enable Naming/ConstantName

    def initialize(app)
      # can also accept *args, and &block which come from Faraday::Connection initializer
      @app = app
    end

    def call(request_env)
      @app.call(request_env).on_complete do |response_env|
        on_complete(response_env)
      end
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def on_complete(env)
      case env[:status]
      when 400
        env[:failure] = Faraday::BadRequestError.new(*response_values(env))
      when 401
        env[:failure] = Faraday::UnauthorizedError.new(*response_values(env))
      when 403
        env[:failure] = Faraday::ForbiddenError.new(*response_values(env))
      when 404
        env[:failure] = Faraday::ResourceNotFound.new(*response_values(env))
      when 407
        # mimic the behavior that we get with proxy requests with HTTPS
        env[:failure] = Faraday::ProxyAuthError.new(*response_values(env, %(407 "Proxy Authentication Required")))
      when 409
        env[:failure] = Faraday::ConflictError.new(*response_values(env))
      when 422
        env[:failure] = Faraday::UnprocessableEntityError.new(*response_values(env))
      when ClientErrorStatuses
        env[:failure] = Faraday::ClientError.new(*response_values(env))
      when ServerErrorStatuses
        env[:failure] = Faraday::ServerError.new(*response_values(env))
      when nil
        env[:failure] = Faraday::NilStatusError.new(*response_values(env))
      end

      env
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def response_values(env, message = nil)
      body = env.body
      # At this point we've already gone through JSON deserialization
      body = SftpgoClient::ApiResponse.new(env.body) if env.body.is_a?(Hash)
      [
        message || "The server responded to `#{env.url.path}` with status #{env.status}, and body:\n```\n#{env.body&.to_s&.truncate(1000)}\n```\nSee .inspect for more detail.",
        {
          status: env.status,
          headers: env.response_headers.to_h,
          body: body,
          request: {
            method: env.method,
            url_path: env.url.path,
            params: env.params,
            headers: env.request_headers,
            body: env.request_body
          }
        }
      ]
    end
  end
end
