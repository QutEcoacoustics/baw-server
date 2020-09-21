# frozen_string_literal: true

module SftpgoClient
  # Storage filesystem details
  class FilesystemConfig < SftpgoClient::SerializableStruct
    FILESYSTEM_LOCAL = 0
    FILESYSTEMS = Types::Strict::Integer.default(FILESYSTEM_LOCAL).enum(FILESYSTEM_LOCAL, 1, 2)

    # @!attribute provider
    #   @return [Integer] Providers:   * `0` - local filesystem   * `1` - S3 Compatible Object Storage   * `2` - Google Cloud Storage
    attribute :provider, FILESYSTEMS
  end
end
