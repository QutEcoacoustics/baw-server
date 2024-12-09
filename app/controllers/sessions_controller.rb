# frozen_string_literal: true

# Handles Restful API Authentication only
# @see http://www.cocoahunter.com/blog/2013/02/13/restful-api-authentication/
# @see controllers/devise/sessions_controller.rb
# https://github.com/heartcombo/devise/blob/main/app/controllers/devise/sessions_controller.rb
class SessionsController < Devise::SessionsController
  include Api::ApiAuth

  # This is Devise's authentication
  #before_action :authenticate_user!, except: [:new, :create]
  skip_before_action :authenticate_user!, only: [:new, :create]

  # remove Devise's default destroy response
  skip_before_action :verify_signed_out_user

  # skip caching current_ability in Current.ability
  # Not sure what he issue here is, but I think the set_current callback
  # happens before the rest of the callbacks in this controller. Once current_ability
  # is called it's value is cached and the callbacks in this controller fail
  skip_before_action :set_current

  # current_user triggers an authentication before our code can run
  skip_around_action :set_then_reset_user_stamper

  # don't check auth for new and create (since this is how to sign in to the api)
  check_authorization except: [:new, :create]

  # disable authenticity token check on sessions#create and #new so harvester can log in
  skip_before_action :verify_authenticity_token, only: [:new, :create]

  # override current_user so it doesn't trigger authentication before we're ready.
  def current_user
    return super unless action_name == 'create'

    return nil unless defined? @user

    super
  end

  respond_to :json

  # GET /security/user
  def show
    authorize! :show, :api_security

    if signed_in?
      session_response_wrapper(
        :ok,
        {
          auth_token: current_user.authentication_token,
          user_name: current_user.user_name,
          user_id: current_user.id
        }
      )
    else
      session_response_wrapper(
        :unauthorized,
        nil,
        I18n.t('devise.failure.unauthenticated'),
        [:sign_in, :sign_up]
      )
    end
  end

  # GET /security/new
  # devise sessions controller
  def new
    session_response_wrapper(
      :ok,
      {
        email: nil,
        login: nil,
        password: nil
      }
    )
  end

  # used by harvester, do not change!
  # POST /security
  # based off of https://github.com/heartcombo/devise/blob/6d32d2447cc0f3739d9732246b5a5bde98d9e032/app/controllers/devise/sessions_controller.rb#L18
  # expected body { user: { login: 'atruskie',        password 'dontlook' } }
  # or            { user: { email: 'atruskie@me.com', password 'dontlook' } }
  # or            {         email: 'atruskie@me.com', password 'dontlook'   }
  # or            {         login: 'atruskie',        password 'dontlook'   }
  def create
    # take care! any call to current_user will trigger authentication before
    # .authenticate! below is called. We override current_user in this controller
    # to avoid this.

    normalize_create_params

    # authenticate with warden
    @user = warden.authenticate({ scope: :user, recall: 'sessions#new' })
    return session_create_fail if @user.nil?

    # sign in with devise
    return session_create_fail unless sign_in(:user, @user)

    set_last_seen_at

    session_response_wrapper(
      :ok,
      {
        auth_token: current_user.authentication_token,
        user_name: current_user.user_name,
        user_id: current_user.id,
        message: I18n.t('devise.sessions.signed_in')
      }
    )
  end

  # DELETE /security
  def destroy
    authorize! :destroy, :api_security

    if signed_in?
      user_name = current_user.user_name
      current_user.clear_authentication_token!
      sign_out(current_user)

      session_response_wrapper(
        :ok,
        {
          user_name:,
          message: I18n.t('devise.sessions.signed_out')
        },
        nil,
        [:sign_in, :sign_up]
      )
    else
      session_response_wrapper(
        :unauthorized,
        nil,
        I18n.t('devise.failure.unauthenticated'),
        [:sign_in, :sign_up]
      )
    end
  end

  private

  def normalize_create_params
    # devise uses request.params so we must modify it
    # backwards compatibility with old harvester, allow non-nested params
    #   e.g. { login: 'atruskie', password 'dontlook' }
    request.params[:user] = request.params.extract!(:email, :password, :login) unless params.key?(:user)

    # collapse email into login
    email = request.params[:user].delete(:email)
    request.params[:user][:login] = email unless email.nil?

    # finally convert to strong parameters to sanitize the payload
    ActionController::Parameters
      .new(request.params)
      .require(:user)
      .require([:login, :password])
  end
end
