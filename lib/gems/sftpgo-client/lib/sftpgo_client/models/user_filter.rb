# frozen_string_literal: true

module SftpgoClient
  # Additional restrictions
  class UserFilter < SftpgoClient::SerializableStruct
    PUBLICKEY = 'publickey'
    PASSWORD = 'password'
    KEYBOARD_INTERACTIVE = 'keyboard-interactive'
    PUBLICKEYPASSWORD = 'publickey+password'

    PUBLICKEYKEYBOARD_INTERACTIVE = 'publickey+keyboard-interactive'
    LOGIN_METHODS = Types::String.enum(
      PUBLICKEY, PASSWORD, KEYBOARD_INTERACTIVE, PUBLICKEYPASSWORD,
      PUBLICKEYKEYBOARD_INTERACTIVE
    )

    SUPPORTED_PROTOCOLS = Types::String.enum('SSH', 'FTP', 'DAV')

    # @!attribute allowed_ip
    #   @return [Array<String>] only clients connecting from these IP/Mask are allowed. IP/Mask must be in CIDR notation as defined in RFC 4632 and RFC 4291, for example \"192.0.2.0/24\" or \"2001:db8::/32\"
    attribute? :allowed_ip, Types::Array.of(Types::Strict::String)

    # @!attribute denied_ip
    #   @return [Array<String>] clients connecting from these IP/Mask are not allowed. Denied rules are evaluated before allowed ones
    attribute? :denied_ip, Types::Array.of(Types::Strict::String)

    # @!attribute denied_login_methods
    #   @return [Array<String>] if null or empty any available login method is allowed
    attribute? :denied_login_methods, Types::Array.of(LOGIN_METHODS)

    # @!attribute denied_protocols
    #   @return [Array<String>] if null or empty any available protocol is allowed
    attribute? :denied_protocols, Types::Array.of(SUPPORTED_PROTOCOLS)

    # @!attribute file_extensions
    #   @return [Array<String>] filters based on file extensions. These restrictions do not apply to files listing for performance reasons, so a denied file cannot be downloaded/overwritten/renamed but it will still be listed in the list of files. Please note that these restrictions can be easily bypassed
    attribute? :file_extensions, Types::Array.of(ExtensionFilter)

    # @!attribute max_upload_file_size
    #   @return [Integer] maximum allowed size, as bytes, for a single file upload. The upload will be aborted if/when the size of the file being sent exceeds this limit. 0 means unlimited. This restriction does not apply for SSH system commands such as `git` and `rsync`
    attribute? :max_upload_file_size, Types::NATURAL
  end
end
