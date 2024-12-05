# frozen_string_literal: true

module SftpgoClient
  # Caches JWTs for the API
  module TokenService
    TOKEN_PATH = 'token'

    # Gets the a JWT token by authenticating with basic auth
    # @return [Dry::Monads::Result<SftpgoClient::Token>]
    def get_token
      response = wrap_response(
        @connection.get(TOKEN_PATH, nil)
      )

      response.fmap { |audio_recording|
        SftpgoClient::Token.new(audio_recording.body)
      }
    end
  end
end
