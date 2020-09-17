# frozen_string_literal: true

$LOAD_PATH.unshift(BawApp.root / 'lib' / 'gems' / 'sftpgo_generated_client' / 'lib')
require 'sftpgo_generated_client'

module BawWorkers
  module UploadService
    # Interface for communicating with our upload service
    class Communicator
      include BawWorkers::UploadService::ApiHelpers

      # The underlying service object for the upload service
      # @return [SftpgoGeneratedClient::ApiClient]
      attr_accessor :service

      # The configuration used for `service`
      # @return [SftpgoGeneratedClient::Configuration]
      attr_accessor :service_config

      # The logger used by the upload communicator
      # @return [Logger]
      attr_accessor :service_logger

      # Create a new upload communicator
      # @param [Hash] upload_service - settings to configure the service
      # @param [Logger] logger - the logger to use
      def initialize(upload_service:, logger:)
        @service_config = SftpgoGeneratedClient::Configuration.new do |config|
          config.host = "#{upload_service.host}:#{upload_service.port}"
          config.scheme = BawApp.dev_or_test? ? 'http' : 'https'
          # Configure HTTP basic authorization: BasicAuth
          config.username = upload_service.username
          config.password = upload_service.password
          config.logger = logger
          config.debugging = BawApp.dev_or_test?
          config.timeout = 30
        end

        @service = SftpgoGeneratedClient::ApiClient.new(@service_config)
        @service_logger = logger
      end

      def admin_url
        "#{@service_config.scheme}://#{@service_config.host}/"
      end

      # Make a user in the upload service. Available for 7 days by default.
      # @return [SftpgoGeneratedClient::User]
      def create_upload_user(username:, password:)
        user = SftpgoGeneratedClient::User.new({
          username: username,
          password: password,
          status: 1, # enabled
          expiration_date: time_to_unix_epoch_milliseconds(Time.now + 7.days),
          #permissions: STANDARD_PERMISSIONS,
          filesystem: STANDARD_FILESYSTEM
        })
        # bug with generated code, it thinks permissions should be an array
        user.permissions = STANDARD_PERMISSIONS

        check_valid(user)

        user_service.add_user(user)
      end

      def toggle_user_enabled(user, enabled:)
        user_id = get_id(user, SftpgoGeneratedClient::User)
        status = enabled ? USER_STATUS_ENABLED : USER_STATUS_DISABLED
        user_service.update_user(user_id, { status: status })
      end

      # Deletes all users
      # @return [Array<String>] - API response messages for each user
      def delete_all_users
        # list users, then delete each
        chain = future { get_all_users }
                .then_flat { |users|
                  zip_futures_over(users) { |user|
                    user_service.delete_user(user.id)
                  }
                }

        chain.value!.map(&:message)
      end

      # Gets all users
      # Actually capped at 500 results, but we don't ever expect more than that.
      def get_all_users
        user_service.get_users({ limit: 500 })
      end

      # Gets the service status (safely)
      # @return [Result]
      def service_status
        handle_error do
          status = provider_status_service.get_provider_status
          status.message || status.error
        end
      end

      # Gets the service version info (safely)
      # @return [Result<Hash>]
      def server_version
        handle_error do
          version_service.get_version.to_hash
        end
      end

      private

      # @return [SftpgoGeneratedClient::UsersApi]
      def user_service
        @user_service ||= SftpgoGeneratedClient::UsersApi.new(@service)
      end

      # @return [SftpgoGeneratedClient::ProviderstatusApi]
      def provider_status_service
        @provider_status_service ||= SftpgoGeneratedClient::ProviderstatusApi.new(@service)
      end

      # @return [SftpgoGeneratedClient::VersionApi]
      def version_service
        @version_service ||= SftpgoGeneratedClient::VersionApi.new(@service)
      end
    end
  end
end
