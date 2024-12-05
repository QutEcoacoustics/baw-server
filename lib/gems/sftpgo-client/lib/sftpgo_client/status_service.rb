# frozen_string_literal: true

module SftpgoClient
  module StatusService
    STATUS_PATH = 'status'

    # Gets the status of the configured providers
    # @return [Dry::Monads::Result<SftpgoClient::ServicesStatus>]
    def get_status
      wrap_response(@connection.get(STATUS_PATH))
        .fmap { |audio_recording| SftpgoClient::ServicesStatus.new(audio_recording.body) }
    end
  end
end
