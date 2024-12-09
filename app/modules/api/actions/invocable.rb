# frozen_string_literal: true

module Api
  module Actions
    # Supports our actions API: https://github.com/QutEcoacoustics/baw-server/wiki/API:-Actions
    module Invocable
      INVOKE_PREFIX = 'invoke_'

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # @return [Array<String>]
        def invocable_actions
          @invocable_actions ||=
            private_instance_methods(include_super: false)
              .filter { |name| name.start_with?(INVOKE_PREFIX) }
              .pluck(INVOKE_PREFIX.length..)
        end
      end

      # Invoke an action on the resource.
      # Supports our actions API: https://github.com/QutEcoacoustics/baw-server/wiki/API:-Actions
      # The arguments are a hash of symbol keys and callback values.
      # There are a lot of validations of these arguments because we want a static
      # list of actions that can be invoked for security reasons.
      # No dynamic invocation of methods from the remote parameter is allowed.
      # The resource is saved if the action is successful.
      def do_invoke
        method_name = validate_action_name

        do_load_resource
        do_authorize_instance

        send(method_name)

        resource = get_resource
        success =  resource.changed? ? resource.save : true

        if success
          # in theory any invocable action always has a side effect, so the result
          # should never be cached
          expires_now
          location = url_for(action: :show, only_path: true)
          head :no_content, location:, content_type: 'application/json'
        else
          respond_change_fail
        end
      end

      # @private
      # @return [Symbol]
      def validate_action_name
        # from the route parameter
        action = params.fetch(:invoke_action)&.to_s
        prefixed_action = :"#{INVOKE_PREFIX}#{action}"

        unless self.class.private_method_defined?(prefixed_action)
          raise CustomErrors::InvalidActionError.new(
            "unknown action: `#{action}`",
            available_actions
          )
        end

        prefixed_action
      end

      def available_actions
        make_invoke_action_urls
      end

      # @private
      # @return [Array<Hash>]
      def make_invoke_action_urls
        self.class.invocable_actions.map { |action|
          {
            text: action,
            url: url_for(action: 'invoke', invoke_action: action, only_path: true)
          }
        }
      end
    end
  end
end
