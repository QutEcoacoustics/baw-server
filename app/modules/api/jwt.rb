# frozen_string_literal: true

module Api
  # Our module for generating JWTs
  module Jwt
    module_function

    ALGORITHM = 'HS256'

    # Create a JWT.
    # By default, the token is immediately useable but will expire in 24 hours.
    # @param subject [Integer] a [User] id to grant the token for
    # @param action [Symbol,nil] an optional action to encode the token for
    # @param resource [Symbol,nil] an optional resource (a controller) to encode the token for
    # @param expiration [ActiveSupport::Duration,nil] how long until the token should expire
    # @param not_before [ActiveSupport::Duration,nil] how long until the token should expire
    # @return [String]
    def encode(
      subject:,
      action: nil,
      resource: nil,
      expiration: 24.hours,
      not_before: nil
    )
      validate(subject:, action:, resource:, expiration:, not_before:)

      payload = {}
      payload['sub'] = subject
      payload['exp'] = expiration.from_now.to_i unless expiration.nil?
      payload['nbf'] = not_before.from_now.to_i unless not_before.nil?
      payload['resource'] = resource.to_s if resource.present?
      payload['action'] = action.to_s if action.present?

      JWT.encode(
        payload,
        Settings.secret_token,
        ALGORITHM
      )
    end

    # Unpack a JWT
    # @param token [String] the token to operate on
    # @return [Api::Jwt::Token] the decoded payload
    def decode(token)
      return nil if token.blank?

      payload, _header = JWT.decode(
        token,
        Settings.secret_token,
        true,
        { algorithm: ALGORITHM }
      )

      hash = {}
      hash[:subject] = payload.delete('sub') if payload.key?('sub')
      hash[:expiration] = payload.delete('exp') if payload.key?('exp')
      hash[:not_before] = payload.delete('nbf') if payload.key?('nbf')
      hash[:resource] = payload.delete('resource') if payload.key?('resource')
      hash[:action] = payload.delete('action') if payload.key?('action')
      hash[:rest] = payload

      Token.new(hash)
    rescue ::JWT::ExpiredSignature => e
      Token.new(expired: true, errored: e)
    rescue ::JWT::ImmatureSignature => e
      Token.new(immature: true, errored: e)
    rescue ::JWT::DecodeError => e
      Token.new(errored: e)
    end

    def validate(
      subject:,
      action: nil,
      resource: nil,
      expiration: 24.hours,
      not_before: nil
    )
      raise ArgumentError, 'subject must be hash' unless subject.is_a?(Integer)

      unless expiration.nil? || expiration.is_a?(ActiveSupport::Duration)
        raise ArgumentError, 'expiration must be a ActiveSupport::Duration'
      end

      unless not_before.nil? || not_before.is_a?(ActiveSupport::Duration)
        raise ArgumentError, 'not_before must be a ActiveSupport::Duration'
      end

      return if resource.nil?

      klass = "#{resource}_controller".classify.safe_constantize

      return if klass.present? && klass < ApplicationController

      raise ArgumentError, 'JWT resource claim must be a valid controller'
    end
  end
end
