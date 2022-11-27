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
      cookies[csrf_cookie_key] = form_authenticity_token if protect_against_forgery? && current_user
    end

    # Simply calls current_user to trigger authentication.
    # We override only so we can customize our API response body.
    def authenticate_user!
      # ripped off https://github.com/heartcombo/devise/blob/6d32d2447cc0f3739d9732246b5a5bde98d9e032/lib/devise/controllers/helpers.rb#L99-L119
      return if current_user

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
        I18n.t('devise.failure.unauthenticated'),
        [:sign_in, :sign_up]
      )
    end
  end
end
