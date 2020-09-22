# frozen_string_literal: true

module SftpgoClient
  # Additional restrictions
  class ExtensionFilter < SftpgoClient::SerializableStruct
    # @!attribute path
    #   @return [Array<String]>] exposed SFTPGo path, if no other specific filter is defined, the filter apply for sub directories too. For example if filters are defined for the paths \"/\" and \"/sub\" then the filters for \"/\" are applied for any file outside the \"/sub\" directory
    attribute :path, Types::Array.of(Types::Strict::String)

    # @!attribute allowed_extensions
    #   @return [Array<String]>] list of, case insensitive, allowed files extension. Shell like expansion is not supported so you have to specify `.jpg` and not `*.jpg`
    attribute? :allowed_extensions, Types::Array.of(Types::Strict::String)

    # @!attribute denied_extensions
    #   @return [Array<String]>] list of, case insensitive, denied files extension. Denied file extensions are evaluated before the allowed ones
    attribute? :denied_extensions, Types::Array.of(Types::Strict::String)
  end
end
