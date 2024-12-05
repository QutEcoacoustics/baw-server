# frozen_string_literal: true

require_relative 'struct/serializable_struct'
require_relative 'validation/types'
require_relative 'validation/validation'

require_relative 'models/api_response'
require_relative 'faraday/response_result_middleware'
require_relative 'faraday/authentication_middleware'

require_relative 'models/extensions_filter'
require_relative 'models/filesystem_config'
require_relative 'models/hook_payload'
require_relative 'models/permission'
require_relative 'models/services_status'
require_relative 'models/token'
require_relative 'models/virtual_folder'
require_relative 'models/user_filter'
require_relative 'models/user'
require_relative 'models/version_info'
require_relative 'status_service'
require_relative 'token_service'
require_relative 'user_service'
require_relative 'version_service'

module SftpgoClient
  # The API interface for a sftpgo service
  class ApiClient
    include Dry::Monads[:result]
    include SftpgoClient::VersionService
    include SftpgoClient::TokenService
    include SftpgoClient::UserService
    include SftpgoClient::StatusService

    JSON_PARSER_OPTIONS = {
      allow_nan: true,
      symbolize_names: true
    }.freeze

    # Stores the API URI this client is configured to use
    # @return [String]
    attr_reader :base_uri

    # The reusable faraday connection. Stores auth, middleware, and API base path.
    # @return [::Faraday::Connection]
    attr_reader :connection

    # The auth token needed to send to the API.
    # @return [Token]
    attr_accessor :token

    # The username used to generate auth tokens
    # @return [String]
    attr_accessor :username

    #  The password used to generate auth tokens
    # @return [String]
    attr_accessor :password

    def initialize(username:, password:, scheme:, host:, port:, base_path: '/api/v2/', logger: nil)
      @base_uri =
        case scheme
        when 'http' then URI::HTTP.build({ host:, port:, path: base_path })
        when 'https' then URI::HTTPS.build({ host:, port:, path: base_path })
        else
          raise ArgumentError, "Unsupported scheme `#{scheme}`"
        end
      @username = username
      @password = password

      log_options = { headers: false, bodies: false }

      @connection = Faraday.new(
        url: @base_uri,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => 'workbench-server/sftpgo-client',
          'Accept' => 'application/json'
        }
      ) do |connection|
        # the order of the middlewares is important!
        # https://lostisland.github.io/faraday/middleware/

        connection.request :json
        connection.response :logger, logger, log_options unless logger.nil?

        # authenticates if required
        connection.use SftpgoClient::AuthenticationMiddleware, self, logger

        connection.use SftpgoClient::ResponseResultMiddleware
        connection.response :parse_dates
        # parser_options needs to be not frozen
        connection.response :json, content_type: /\bjson$/, parser_options: JSON_PARSER_OPTIONS.dup
        connection.response :encoding
      end
    end

    private

    # Wraps a result in monadic Result
    def wrap_response(result)
      # failure is the custom prop we add in the ResponseResultMiddleware
      return Failure(result.env[:failure]) if result&.env&.[](:failure)

      return Failure(result) unless result.success?

      Success(result)
    end
  end
end
