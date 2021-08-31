# frozen_string_literal: true

$LOAD_PATH.unshift((BawApp.root / 'lib' / 'gems' / 'sftpgo-client' / 'lib').to_s)
require 'sftpgo_client'

module BawWorkers
  module UploadService
    # Interface for communicating with our upload service
    class Communicator
      include BawWorkers::UploadService::ApiHelpers

      # The underlying API client object for the upload service
      # @return [SftpgoClient::ApiClient]
      attr_accessor :client

      # The logger used by the upload communicator
      # @return [Logger]
      attr_accessor :service_logger

      # Create a new upload communicator
      # @param [Hash] config - settings to configure the service
      # @param [Logger] logger - the logger to use
      def initialize(config:, logger:)
        @client = SftpgoClient::ApiClient.new(
          username: config.username,
          password: config.password,
          scheme: BawApp.http_scheme,
          host: config.host,
          port: config.port,
          logger: logger
        )
        @service_logger = logger
      end

      def admin_url
        @admin_url ||= URI.join(@client.base_uri, '/').to_s
      end

      # Make a user in the upload service. Available for 7 days by default.
      # @return [SftpgoClient::User]
      def create_upload_user(username:, password:)
        user = SftpgoClient::User.new({
          username: username,
          password: password,
          public_keys: nil,
          home_dir: nil, # will default to mount/username, e.g. /data/harvest_1
          status: SftpgoClient::User::USER_STATUS_ENABLED,
          expiration_date: time_to_unix_epoch_milliseconds(Time.now + 7.days),
          permissions: STANDARD_PERMISSIONS,
          filesystem: STANDARD_FILESYSTEM
        })

        ensure_successful_response(client.create_user(user))
      end

      # Updates a user's status (enabled or disabled)
      # @return [SftpgoClient::ApiResponse]
      def set_user_status(user, enabled:)
        user_name = get_id(user, SftpgoClient::User)
        status = enabled ? USER_STATUS_ENABLED : USER_STATUS_DISABLED
        response = client.update_user(user_name: user_name, user: { status: status })
        ensure_successful_response(response)
      end

      # Gets a user
      # @param [SftpgoClient::User,Integer] A user class to extract an id from, or an id
      # @return [SftpgoClient::User]
      def get_user(user)
        user_name = get_id(user, SftpgoClient::User)

        ensure_successful_response(client.get_user(user_name: user_name))
      end

      # Deletes all users
      # @return [Array<String>] - API response messages for each user
      def delete_all_users
        # list users, then delete each
        chain = future { get_all_users }
                .then_flat { |users|
                  zip_futures_over(users) { |user|
                    ensure_successful_response(client.delete_user(user_name: get_id(user, SftpgoClient::User)))
                  }
                }

        chain.value!.map(&:message)
      end

      # Gets all users
      # Actually capped at 500 results, but we don't ever expect more than that.
      # @return [Array<SftpgoClient::User>]
      def get_all_users
        ensure_successful_response(client.get_users(limit: SftpgoClient::UserService::MAXIMUM_LIMIT))
      end

      # Gets the service status (safely)
      # @return  [Dry::Monads::Result::Success<SftpgoClient::ServicesStatus>,Dry::Monads::Result::Failure<SftpgoClient::ApiResponse>]
      def service_status
        client.get_status
      end

      # Gets the service version info (safely)
      # @return [Dry::Monads::Result::Success<SftpgoClient::VersionInfo>,Dry::Monads::Result::Failure<SftpgoClient::ApiResponse>]
      def server_version
        client.get_version
      end
    end
  end
end
