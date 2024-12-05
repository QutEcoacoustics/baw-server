# frozen_string_literal: true

module Api
  # Our module for generating JWTs
  module Jwt
    # A deserialized token
    class Token < ::Dry::Struct
      transform_keys(&:to_sym)

      # @!attribute [r] rest
      #   the rest of the payload
      #   @return [String]
      attribute :rest, ::BawWorkers::Dry::Types::Hash.default({}.freeze)

      # @!attribute [r] subject
      #   the subject (sub) - for use this is a [User] id
      #   @return [String]
      attribute? :subject, ::BawWorkers::Dry::Types::ID

      # @!attribute [r] resource
      #   the resource (a cancancan resource)
      #   this token is valid for
      #   @return [String]
      attribute? :resource, ::BawWorkers::Dry::Types::Coercible::Symbol

      # @!attribute [r] action
      #   the action (a cancancan action)
      #   this token is valid for
      #   @return [String]
      attribute? :action, ::BawWorkers::Dry::Types::Coercible::Symbol

      # @!attribute [r] expiration
      #   the expiry (exp) claim
      #   @return [Time]
      attribute? :expiration, ::BawWorkers::Dry::Types::UnixTime

      # @!attribute [r] not_before
      #   the not before (nbf) claim
      #   @return [Time]
      attribute? :not_before, ::BawWorkers::Dry::Types::UnixTime

      # @!attribute [r] expired
      #    has the token expired
      #   @return [Boolean]
      attribute :expired, ::BawWorkers::Dry::Types::Bool.default(false)

      # @!attribute [r] immature
      #   was the token used before the not before claim
      #   @return [Boolean]
      attribute :immature, ::BawWorkers::Dry::Types::Bool.default(false)

      # @!attribute [r] errored
      #   did any other error occur
      #   @return [Boolean]
      attribute :errored, ::BawWorkers::Dry::Types::Nominal::Any.default(nil)

      def valid?
        !expired && !immature && errored.blank?
      end
    end
  end
end
