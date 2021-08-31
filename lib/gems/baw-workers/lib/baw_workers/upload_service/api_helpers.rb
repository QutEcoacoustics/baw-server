# frozen_string_literal: true

module BawWorkers
  module UploadService
    # Convenience methods for working with the sftpgo service
    # Reference: https://github.com/drakkan/sftpgo/blob/master/httpd/schema/openapi.yaml
    module ApiHelpers
      include ::Dry::Monads[:try]
      include ::Dry::Monads[:task]

      # http://ruby-concurrency.github.io/concurrent-ruby/master/file.promises.out.html
      include Concurrent::Promises::FactoryMethods
      def default_executor
        :fast
      end

      USER_STATUS_ENABLED = 1
      USER_STATUS_DISABLED = 0
      FILESYSTEM_LOCAL = 0

      # Returns a permissions hash used for making a new user.
      # Basically the user has permission to access anything in the root dir.
      # This is ok because each account is chrooted to its home directory, and
      # further, the docker container is isolated to the upload directory.
      STANDARD_PERMISSIONS =
        {
          '/' => [SftpgoClient::Permission::ALL]
        }.freeze

      STANDARD_FILESYSTEM = SftpgoClient::FilesystemConfig.new({
        provider: FILESYSTEM_LOCAL
      }).freeze

      private

      def time_to_unix_epoch_milliseconds(time)
        time.to_i * 1000
      end

      # Return value or raise unless valid
      # @param [::Dry::Monads::Result] result
      # @return [Object] the unwrapped value
      def ensure_successful_response(result)
        return result.value! if result.success?

        raise result.failure
      end

      def get_id(subject, target_class)
        case subject
        when target_class
          subject.username
        when String
          subject
        else
          raise ArgumentError, "Not a #{target_class.name} or user name: #{subject}"
        end
      end
    end
  end
end
