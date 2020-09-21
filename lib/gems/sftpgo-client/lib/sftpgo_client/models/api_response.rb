# frozen_string_literal: true

module SftpgoClient
  # Generic message/error response
  class ApiResponse < SftpgoClient::SerializableStruct
    # @!attribute message
    #   @return [String]  message, can be empty
    attribute? :message, Types::Strict::String

    # @!attribute error
    #   @return [String] error description if any
    attribute? :error, Types::Strict::String
  end
end
