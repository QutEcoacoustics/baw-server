# frozen_string_literal: true

module Api
  module AuthStrategies
    # Authorization: Bearer <token>
    # https://github.com/wardencommunity/warden/wiki/Strategies
    class Jwt < ::Devise::Strategies::Base
      NAME = :jwt
      ENV_KEY = :api_auth_strategies_jwt
      HEADER = 'Authorization'
      HEADER_FORMAT = /Bearer ([-_.A-Za-z0-9]+)/
      HEADER_KEY = /Bearer/i
      INCORRECT_FORMAT = 'Incorrect bearer format'

      def valid?
        !parse_token.nil?
      end

      def authenticate!
        token = parse_token

        return token unless token.is_a?(String)

        jwt = ::Api::Jwt.decode(token)
        unless jwt.valid?
          Rails.logger.debug('JWT authorization failed', jwt:)
          # intentionally obscure here, this is a public message.
          # todo: add more context if needed
          message = ''
          message = ': token is expired' if jwt.expired
          message = ': token is immature' if jwt.immature

          return fail!("JWT decode error#{message}")
        end

        user = User.find_by(id: jwt.subject)

        return fail!("Unknown user id `#{jwt.subject}` in JWT sub claim") if user.nil?

        env[ENV_KEY] = jwt
        success! user
      end

      protected

      # @return [String,nil,Symbol] the bearer token if valid, or nil if the header is not
      def parse_token
        header = authorization_header

        return if header.blank?

        parse_header(header)
      end

      def authorization_header
        request.headers['Authorization']&.to_s
      end

      # @return [String,nil,Symbol]
      #   the bearer token if valid,
      #   or nil if the header is not
      #   or a symbol if the header is malformed
      #   in the right format
      def parse_header(header)
        match = HEADER_FORMAT.match(header)

        return match[1] if match

        return fail!(INCORRECT_FORMAT) if HEADER_KEY.match(header)

        nil
      end
    end
  end
end
