# frozen_string_literal: true

module Api
  module ApiAuth
    extend ActiveSupport::Concern

    private

    # Authenticate user.
    # @see https://gist.github.com/josevalim/fb706b1e933ef01e4fb6
    # @return [void]
    def authenticate_user_custom!
      sign_in_params = get_sign_in_params
      do_sign_in(sign_in_params)
    end

    def do_sign_in(sign_in_params)
      # only sign in if we have a valid resource and the comparison was successful.
      sign_in sign_in_params[:resource], store: false if sign_in_params[:resource] && sign_in_params[:comparison]
    end

    # Retrieve sign in parameters.
    # @example
    #   {"login": "user@example.com", "password": "user_password"}
    #   {"login": "user_name", "password": "user_password"}
    #   (header) Authorization: 'Token token="tokenvalue"'
    # @return [Hash] sign in parameters.
    def get_sign_in_params
      # available parameters
      email = params[:email].presence
      login = params[:login].presence
      password = params[:password].presence

      token, token_options = get_token

      # Use the email or login or token to get the user resource.
      resource = nil
      if login
        resource = User.find_for_database_authentication(login: login)
      elsif email
        resource = User.find_for_database_authentication(email: email)
      elsif token
        # allow login with only token
        resource = User.find_by_authentication_token(token)
      end

      # Compare the password or token.
      comparison = false
      if password && resource
        comparison = resource.valid_password?(password)
      elsif token
        comparison = valid_token_login?(resource, token)
      end

      {
        email: email,
        login: login,
        token: token,
        password: password,
        token_options: token_options,
        resource: resource,
        comparison: comparison
      }
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

    # Get the auth token.
    # @return [String]
    def get_token
      token = params[:user_token].presence

      token_options = {}

      # get token from Authentication header
      if token.blank?
        # enable devise to get auth token in header
        # expects header with name "Authorization" and value 'Token token="tokenvalue"'
        # @see https://groups.google.com/forum/?fromgroups#!topic/plataformatec-devise/o3Gqgl0yUZo
        # @see http://api.rubyonrails.org/v3.2.19/classes/ActionController/HttpAuthentication/Token.html
        token_with_options = ActionController::HttpAuthentication::Token.token_and_options(request)
        token = token_with_options[0] if token_with_options
        token_options = token_with_options[1] if token_with_options
      end

      [token, token_options]
    end

    # Was an api authorisation method used?
    #   (header) Authorization: 'Token token="<tokenvalue>"'
    #   (params) user_token=<tokenvalue>
    # @return [Boolean]
    def api_auth_success?
      token, token_options = get_token

      resource = nil
      resource = User.find_by_authentication_token(token) unless token.blank?

      comparison = valid_token_login?(resource, token)

      # token, resource, and comparison must all be valid
      !token.blank? && !resource.blank? && comparison
    end

    def valid_token_login?(resource, token)
      comparison = false

      if resource && token
        # Notice how we use Devise.secure_compare to compare the token
        # in the database with the token given in the params, mitigating
        # timing attacks.
        comparison = Devise.secure_compare(resource.authentication_token, token)

        # if token is given, but does not match, it is invalid
        token_was_invalid = !comparison
      else
        token_was_invalid = resource.nil? && !token.blank?
      end

      raise CanCan::AccessDenied, "Invalid authentication token '#{token}'." if token_was_invalid

      comparison
    end
  end
end
