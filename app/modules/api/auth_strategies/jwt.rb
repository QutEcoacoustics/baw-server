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

      def valid?
        !parse_token.nil?
      end

      def authenticate!
        token = parse_token

        return if token.nil?

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

        return fail!("Unknown user in JWT sub claim #{jwt.subject}") if user.nil?

        env[ENV_KEY] = jwt
        success! user
      end

      protected

      # @return [String,nil] the bearer token if valid, or nil if the header is not
      def parse_token
        header = authorization_header

        return unless header.present?

        parse_header(header)
      end

      def authorization_header
        request.headers['Authorization']&.to_s
      end

      # @return [String,nil] the bearer token if valid, or nil if the header is not
      #   in the right format
      def parse_header(header)
        match = HEADER_FORMAT.match(header)

        return nil unless match

        match[1]
      end
    end
  end
end
