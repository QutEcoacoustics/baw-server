# frozen_string_literal: true

module SftpgoClient
  # Generic message/error response
  class ServicesStatus < SftpgoClient::SerializableStruct
    # @!attribute ssh
    #   @return [Hash]
    attribute? :ssh, Types::Strict::Hash

    # @!attribute ftp
    #   @return [Hash]
    attribute? :ftp, Types::Strict::Hash

    # @!attribute webdav
    #   @return [Hash]
    attribute? :webdav, Types::Strict::Hash

    # @!attribute data_provider
    #   @return [Hash]
    attribute? :data_provider, Types::Strict::Hash

    # @!attribute defender
    #   @return [Hash]
    attribute? :defender do
      attribute :is_active, Types::Strict::Bool
    end
  end
end
