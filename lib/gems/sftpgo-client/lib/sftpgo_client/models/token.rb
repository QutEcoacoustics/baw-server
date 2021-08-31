# frozen_string_literal: true

module SftpgoClient
  # Additional restrictions
  class Token < SftpgoClient::SerializableStruct
    # @!attribute access_token
    #   @return [String]
    attribute :access_token, Types::Strict::String

    # @!attribute expires_at
    #   @return [DateTime]
    attribute :expires_at, Types::Time
  end
end
