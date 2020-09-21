# frozen_string_literal: true

module SftpgoClient
  # Additional restrictions
  class VersionInfo < SftpgoClient::SerializableStruct
    # @!attribute version
    #   @return [String]
    attribute :version, Types::Strict::String

    # @!attribute build_date
    #   @return [DateTime]
    attribute :build_date, Types::Time

    # @!attribute commit_hash
    #   @return [String]
    attribute :commit_hash, Types::Strict::String

    # @!attribute features
    #   @return [Array<String>] Features for the current build. Available features are \"portable\", \"bolt\", \"mysql\", \"sqlite\", \"pgsql\", \"s3\", \"gcs\", \"metrics\". If a feature is available it has a \"+\" prefix, otherwise a \"-\" prefix
    attribute :features, Types::Array.of(Types::Strict::String)
  end
end
