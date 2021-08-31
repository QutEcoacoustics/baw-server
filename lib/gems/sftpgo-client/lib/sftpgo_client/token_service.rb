# frozen_string_literal: true

module SftpgoClient
  module TokenService
    TOKEN_PATH = 'token'

    # Gets the a JWT token
    # @return [Dry::Monads::Result<SftpgoClient::Token>]
    def get_token
      header = basic_header_from(@username, @password)

      response = wrap_response(
        @connection.get(TOKEN_PATH, nil, {
          Faraday::Request::Authorization::KEY => header
        })
      )

      response.fmap { |r| SftpgoClient::Token.new(r.body) }
    end

    def basic_header_from(login, pass)
      value = Base64.encode64("#{login}:#{pass}")
      value.delete!("\n")
      "Basic #{value}"
    end
  end
end
