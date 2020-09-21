module SftpgoClient
  module ProviderStatusService
    STATUS_PATH = 'providerstatus'.freeze

    # Gets the status of the configured provider
    # @return [Dry::Monads::Result<SftpgoClient::ApiResponse>]
    def get_provider_status
      wrap_response(@connection.get(STATUS_PATH)).fmap { |r| SftpgoClient::ApiResponse.new(r.body) }
    end
  end
end
