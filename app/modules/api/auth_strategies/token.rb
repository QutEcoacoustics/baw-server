# frozen_string_literal: true

module Api
  module AuthStrategies
    # Authorization: Token token="<token>"
    # https://github.com/wardencommunity/warden/wiki/Strategies
    class Token < ::Devise::Strategies::Base
      NAME = :token

      HEADER = 'Authorization'
      # the rails token auth which this is based on supports sending
      # hashes of extra data, but we never use that so we're not going
      # to match it.
      # https://api.rubyonrails.org/v3.2.19/classes/ActionController/HttpAuthentication/Token.html
      # OK: so our token generation is base64url encoded so our regex could be more strict
      #   but our tests use all sorts of random strings and I don't want to fix every
      #   variant we have....
      HEADER_FORMAT = /Token token="(.+)"/
      HEADER_KEY = /Token/i
      INVALID_TOKEN = 'Invalid authentication token'
      INCORRECT_FORMAT = 'Incorrect token format'
      EXPIRED_TOKEN = 'Expired authentication token'

      def valid?
        !parse_token.nil?
      end

      def authenticate!
        token = parse_token
        return token unless token.is_a?(String)

        return fail!(INVALID_TOKEN) if token.blank?

        user = User.where.not(authentication_token: nil).find_by(authentication_token: token)

        # intentionally obscure here, this is a public message.
        return fail!(INVALID_TOKEN) if user.nil?

        # Notice how we use Devise.secure_compare to compare the token
        # in the database with the token given in the params, mitigating
        # timing attacks.
        comparison = Devise.secure_compare(user.authentication_token, token)

        return fail!(INVALID_TOKEN) unless comparison

        # allow access within a rolling window
        return fail!(EXPIRED_TOKEN) if user.expired_authentication_token?

        success! user
      end

      protected

      # @return [String,nil] the bearer token if valid, or nil if the header is not
      def parse_token
        header = authorization_header

        if header.present?
          parse_header(header)
        else
          # see if QSP has the token
          params.fetch(:user_token, nil)&.presence
        end
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
