# frozen_string_literal: true

module Api
  # A module for authorizing via tokens.
  module ApiAuth
    class AccessDenied < StandardError; end

    extend ActiveSupport::Concern

    private

    # Gets a JWT token instance if we signed in with a JWT
    # @return [::Api::Jwt::Token,nil]
    def jwt
      env.fetch(::Api::AuthStrategies::Jwt::ENV_KEY, nil)
    end

    # CSRF protection is enabled for API.
    # Set CSRF token into a cookie only when CSRF protection is enabled and user is logged in.
    # cookies can only be accessed by js from the same origin (protocol, host and port) as the response.
    # This enforces login via the UI only, since requests without a logged in user won't have access to the CSRF cookie.
    # http://stackoverflow.com/questions/14734243/rails-csrf-protection-angular-js-protect-from-forgery-makes-me-to-log-out-on
    # http://stackoverflow.com/questions/7600347/rails-api-design-without-disabling-csrf-protection
    def set_csrf_cookie
      csrf_cookie_key = 'XSRF-TOKEN'
      return unless protect_against_forgery? && current_user

      cookies[csrf_cookie_key] = {
        value: form_authenticity_token,
        # ? make sure these values mirror the settings in config/initializers/session_store.rb
        secure: !BawApp.dev_or_test?,
        same_site: BawApp.dev_or_test? ? :lax : :none
      }
    end

    # Simply calls current_user to trigger authentication.
    # We override only so we can customize our API response body.
    # @param _opts [Hash] options (not used) - for compatibility with Devise method signature
    def authenticate_user!(_opts = {})
      # ripped off https://github.com/heartcombo/devise/blob/6d32d2447cc0f3739d9732246b5a5bde98d9e032/lib/devise/controllers/helpers.rb#L99-L119
      # if valid user then all good
      # current_user calls warden.authenticate which will set warden.result
      return if current_user

      # if there was something wrong with authentication (like an invalid token)
      # then fail here.
      # This is a backwards compatibility branch. We _could_ allow someone with
      # an invalid token to access a public resource, but
      #   a) that's a breaking change
      #   and b) I think it's better to fail. More secure? More rigid? More consistent?
      return session_unauthenticated if warden.result == :failure

      # if here: no user, and no auth failure, so is this a public resource?
      # if so continue.
      return unless should_authenticate_user?

      # Otherwise this is a non-public resource. A user is required, so fail.
      session_unauthenticated
    end

    def session_response_wrapper(status_symbol, data, error_details = nil, error_links = [])
      built_response = Settings.api_response.build(
        status_symbol,
        data,
        { error_details:, error_links: }
      )
      render json: built_response, status: status_symbol, layout: false
    end

    def session_create_fail
      session_response_wrapper(
        :unauthorized,
        nil,
        'Incorrect user name, email, or password. Alternatively, you may need to confirm your account or it may be locked.',
        [:confirm, :reset_password, :resend_unlock]
      )
    end

    def session_unauthenticated
      session_response_wrapper(
        :unauthorized,
        nil,
        warden&.message || I18n.t('devise.failure.unauthenticated'),
        [:sign_in, :sign_up]
      )
    end
  end
end
