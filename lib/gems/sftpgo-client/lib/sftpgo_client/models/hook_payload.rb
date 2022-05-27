# frozen_string_literal: true

module SftpgoClient
  # The payload we expect from a web hook issued by sftpgo
  # https://github.com/drakkan/sftpgo/blob/main/docs/custom-actions.md
  class HookPayload < SftpgoClient::SerializableStruct
    STATUS_NO_ERROR = 1
    STATUS_GENERIC_ERROR = 2
    STATUS_QUOTA_EXCEEDED = 3
    STATUSES = Types::Strict::Integer.enum(STATUS_NO_ERROR, STATUS_GENERIC_ERROR, STATUS_QUOTA_EXCEEDED)

    ACTIONS_DOWNLOAD = 'download'
    ACTIONS_PRE_DOWNLOAD = 'pre-download'
    ACTIONS_UPLOAD = 'upload'
    ACTIONS_PRE_UPLOAD = 'pre-upload'
    ACTIONS_DELETE = 'delete'
    ACTIONS_PRE_DELETE = 'pre-delete'
    ACTIONS_RENAME = 'rename'
    ACTIONS_MKDIR = 'mkdir'
    ACTIONS_RMDIR = 'rmdir'
    ACTIONS_SSH_CMD = 'ssh_cmd'
    ACTIONS = Types::Strict::String.enum(
      ACTIONS_DOWNLOAD, ACTIONS_PRE_DOWNLOAD, ACTIONS_UPLOAD, ACTIONS_PRE_UPLOAD, ACTIONS_DELETE,
      ACTIONS_PRE_DELETE, ACTIONS_RENAME, ACTIONS_MKDIR, ACTIONS_RMDIR, ACTIONS_SSH_CMD
    )

    # @!attribute action
    #   @return [String] action
    attribute :action, ACTIONS

    # @!attribute username
    #   @return [String] username
    attribute :username, Types::Strict::String

    # @!attribute path
    #   @return [String] path
    attribute :path, Types::Strict::String

    # @!attribute target_path
    #   @return [String] target_path
    #   included for rename action and sftpgo-copy SSH command
    attribute? :target_path, Types::Strict::String

    # @!attribute virtual_path
    #   @return [String] virtual_path
    #   virtual path, seen by SFTPGo users
    attribute :virtual_path, Types::Strict::String

    # @!attribute virtual_target_path
    #   @return [String] virtual_target_path
    #   included for rename action and sftpgo-copy SSH command
    attribute? :virtual_target_path, Types::Strict::String

    # @!attribute ssh_cmd
    #   @return [String] ssh_cmd
    #    string, included for ssh_cmd action
    attribute? :ssh_cmd, Types::Strict::String

    # @!attribute file_size
    #   @return [Integer] file_size
    #    int64, included for pre-upload, upload, download, delete actions if the file size is greater than 0
    attribute? :file_size, Types::NATURAL

    # @!attribute fs_provider
    #   @return [Integer] fs_provider
    #    int64, included for pre-upload, upload, download, delete actions if the file size is greater than 0
    attribute :fs_provider, FilesystemConfig::FILESYSTEMS

    # @!attribute bucket
    #   @return [String] bucket
    #   included for S3, GCS and Azure backends
    attribute? :bucket, Types::Strict::String

    # @!attribute endpoint
    #   @return [String] endpoint
    #   included for S3, SFTP and Azure backend if configured
    attribute? :endpoint, Types::Strict::String

    # @!attribute status
    #   @return [Integer] status
    #   Status for upload, download and ssh_cmd actions.
    #   1 means no error, 2 means a generic error occurred, 3 means quota exceeded error
    attribute :status, STATUSES

    # @!attribute protocol
    #   @return [String] protocol
    #   Possible values are SSH, SFTP, SCP, FTP, DAV, HTTP, HTTPShare, OIDC, DataRetention
    attribute :protocol, Types::Strict::String

    # @!attribute ip
    #   @return [::IPAddr] ip
    #   The action was executed from this IP address
    attribute :ip, Types::IPAddr

    # @!attribute session_id
    #   @return [String] session_id
    #   Unique protocol session identifier. For stateless protocols such as HTTP the session id will change for each request
    attribute :session_id, Types::Strict::String

    # @!attribute open_flags
    #   @return [Integer] open_flags
    #   File open flags, can be non-zero for pre-upload action.
    #   If file_size is greater than zero and file_size&512 == 0 the target file will not be truncated
    attribute? :open_flags, Types::Strict::Integer

    # @!attribute timestamp
    #   @return [Integer] timestamp
    #   Event timestamp as nanoseconds since epoch
    attribute :timestamp, Types::Strict::Integer
  end
end
