# frozen_string_literal: true

module SftpgoClient
  module VersionService
    VERSION_PATH = 'version'

    # Gets the version of SFTPGO that is running
    # @return [Dry::Monads::Result<SftpgoClient::VersionInfo>]
    def get_version
      response = wrap_response(@connection.get(VERSION_PATH))

      response.fmap { |r| SftpgoClient::VersionInfo.new(r.body) }
    end
  end
end
