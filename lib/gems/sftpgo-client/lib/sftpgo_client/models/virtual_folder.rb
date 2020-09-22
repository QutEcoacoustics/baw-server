# frozen_string_literal: true

module SftpgoClient
  # Additional restrictions
  class VirtualFolder < SftpgoClient::SerializableStruct
    # @!attribute id
    #   @return [Integer]
    attribute? :id, Types::ID

    # @!attribute mapped_path
    #   @return [String] absolute filesystem path to use as virtual folder. This field is unique
    attribute :mapped_path, Types::Strict::String

    # @!attribute used_quota_size
    #   @return [Integer]
    attribute? :used_quota_size, Types::NATURAL

    # @!attribute used_quota_files
    #   @return [Integer]
    attribute? :used_quota_files, Types::NATURAL

    # @!attribute last_quota_update
    #   @return [Integer]
    # Last quota update as unix timestamp in milliseconds
    attribute? :last_quota_update, Types::NATURAL

    # @!attribute users
    #   @return [Array<String>] list of usernames associated with this virtual folder
    attribute :users, Types::Array.of(Types::Strict::String)

    # @!attribute virtual_path
    #   @return [String]
    attribute :virtual_path, Types::Strict::String

    # @!attribute quota_size
    #   @return [Integer] Quota as size in bytes. 0 menas unlimited, -1 means included in user quota. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed
    attribute :quota_size, Types::Strict::Integer.constrained(gteq: -1)

    # @!attribute quota_files
    #   @return [Integer] Quota as number of files. 0 menas unlimited, , -1 means included in user quota. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed
    attribute :quota_files, Types::Strict::Integer.constrained(gteq: -1)
  end
end
