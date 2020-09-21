# frozen_string_literal: true

module SftpgoClient
  class User < SftpgoClient::SerializableStruct
    USER_STATUS_ENABLED = 1
    USER_STATUS_DISABLED = 0
    STATUSES = Types::Strict::Integer.enum(USER_STATUS_ENABLED, USER_STATUS_DISABLED)

    FILESYSTEM_LOCAL = 0
    FILESYSTEMS = Types::Strict::Integer.enum(FILESYSTEM_LOCAL, 1, 2)

    # @!attribute id
    #   @return [Integer]
    attribute? :id, Types::ID

    # @!attribute status
    #   @return [Integer] status:   * `0` user is disabled, login is not allowed   * `1` user is enabled
    attribute :status, STATUSES

    # @!attribute username
    #   @return [String] username is unique
    attribute :username, Types::Strict::String

    # @!attribute expiration_date
    #   @return [Integer] expiration date as unix timestamp in milliseconds. An expired account cannot login. 0 means no expiration
    attribute :expiration_date, Types::NATURAL

    # @!attribute password
    #   @return [String] password or public key/SSH user certificate are mandatory. If the password has no known hashing algo prefix it will be stored using argon2id. You can send a password hashed as bcrypt or pbkdf2 and it will be stored as is. For security reasons this field is omitted when you search/get users
    attribute? :password, Types::Strict::String

    # @!attribute public_keys
    #   @return [String] a password or at least one public key/SSH user certificate are mandatory.
    attribute? :public_keys, Types::Strict::String.optional

    # @!attribute home_dir
    #   @return [String] path to the user home directory. The user cannot upload or download files outside this directory. SFTPGo tries to automatically create this folder if missing. Must be an absolute path
    attribute :home_dir, Types::Strict::String.optional

    # @!attribute virtual_folders
    #   @return [Array<Sftpgo::VirtualFolder]>] mapping between virtual SFTPGo paths and filesystem paths outside the user home directory. Supported for local filesystem only. If one or more of the specified folders are not inside the dataprovider they will be automatically created. You have to create the folder on the filesystem yourself
    attribute :virtual_folders, Types::Array.of(SftpgoClient::VirtualFolder).default([].freeze)

    # @!attribute uid
    #   @return [Integer] if you run SFTPGo as root user, the created files and directories will be assigned to this uid. 0 means no change, the owner will be the user that runs SFTPGo. Ignored on windows
    attribute :uid, Types::UINT32.default(0)

    # @!attribute gid
    #   @return [Integer] if you run SFTPGo as root user, the created files and directories will be assigned to this gid. 0 means no change, the group will be the one of the user that runs SFTPGo. Ignored on windows
    attribute :gid, Types::UINT32.default(0)

    # @!attribute max_sessions
    #   @return [Integer] Limit the sessions that a user can open. 0 means unlimited
    attribute :max_sessions, Types::UINT32.default(0)

    # @!attribute quota_size
    #   @return [Integer] Quota as size in bytes. 0 means unlimited. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed
    attribute :quota_size, Types::NATURAL.default(0)

    # @!attribute quota_files
    #   @return [Integer] Quota as number of files. 0 means unlimited. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed
    attribute :quota_files, Types::UINT32.default(0)

    # @!attribute permissions
    #   @return [Hash<String, Array<String>>]
    attribute :permissions, Types::Hash.map(
      Types::Coercible::String,
      Types::Array.of(SftpgoClient::Permission::PERMISSIONS)
    )

    # @!attribute used_quota_size
    #   @return [Integer]
    attribute? :used_quota_size, Types::NATURAL

    # @!attribute used_quota_files
    #   @return [Integer]
    attribute? :used_quota_files, Types::UINT32

    # @!attribute last_quota_update
    #   @return [Integer] Last quota update as unix timestamp in milliseconds
    attribute? :last_quota_update, Types::NATURAL

    # @!attribute upload_bandwidth
    #   @return [Integer] Maximum upload bandwidth as KB/s, 0 means unlimited
    attribute :upload_bandwidth, Types::UINT32.default(0)

    # @!attribute download_bandwidth
    #   @return [Integer] Maximum download bandwidth as KB/s, 0 means unlimited
    attribute :download_bandwidth, Types::UINT32.default(0)

    # @!attribute last_login
    #   @return [Integer] Last user login as unix timestamp in milliseconds
    attribute? :last_login, Types::NATURAL

    # @!attribute filters
    #   @return [Array<SftpgoClient::UserFilter>]
    attribute :filters, SftpgoClient::UserFilter.optional.default(nil)

    # @!attribute filesystem
    #   @return [SftpgoClient::FilesystemConfig]
    attribute :filesystem, SftpgoClient::FilesystemConfig
  end
end
