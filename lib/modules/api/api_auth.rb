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
      if sign_in_params[:resource] && sign_in_params[:comparison]
        sign_in sign_in_params[:resource], store: false
      else
        nil
      end
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
      token = params[:user_token].presence
      password = params[:password].presence
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
      elsif token && resource
        # Notice how we use Devise.secure_compare to compare the token
        # in the database with the token given in the params, mitigating
        # timing attacks.
        comparison = Devise.secure_compare(resource.authentication_token, token)
      end

      {
          email:email,
          login:login,
          token:token,
          password: password,
          token_options:token_options,
          resource:resource,
          comparison: comparison
      }
    end

  end
end