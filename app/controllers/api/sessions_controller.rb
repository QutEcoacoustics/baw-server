# Handles Restful API Authentication only
# @see http://www.cocoahunter.com/blog/2013/02/13/restful-api-authentication/
# @see controllers/devise/sessions_controller.rb
class Api::SessionsController < Devise::SessionsController
  include Api::ApiAuth

  # custom user authentication
  before_action :authenticate_user_custom!, except: [:new, :create]

  # This is Devise's authentication
  before_action :authenticate_user!

  # remove Devise's default destroy response
  skip_before_action :verify_signed_out_user

  # don't check auth for new and create (since this is how to sign in to the api)
  check_authorization except: [:new, :create]

  # disable authenticity token check on sessions#create and #new so harvester can log in
  skip_before_action :verify_authenticity_token, only: [:new, :create]

  respond_to :json

  # GET /security/new
  # devise sessions controller
  def new
    response_wrapper(
        :ok,
        {
            email: nil,
            login: nil,
            password: nil
        })
  end

  # GET /security
  def show
    authorize! :show, :api_security

    if signed_in?
      response_wrapper(
          :ok,
          {
              auth_token: current_user.authentication_token,
              #email: current_user.email,
              user_name: current_user.user_name
          })
    else
      response_wrapper(
          :unauthorized,
          nil,
          I18n.t('devise.failure.unauthenticated'),
          [:sign_in, :sign_up])
    end
  end

  # used by harvester, do not change!
  # POST /security
  def create
    sign_in_params = get_sign_in_params
    result = do_sign_in(sign_in_params)

    if result.nil?
      response_wrapper(
          :unauthorized,
          nil,
          'Incorrect user name, email, or password. Alternatively, you may need to confirm your account or it may be locked.',
          [:confirm, :reset_password, :resend_unlock])
    else
      response_wrapper(
          :ok,
          {
              auth_token: sign_in_params[:resource].authentication_token,
              #email: sign_in_params[:resource].email,
              user_name: sign_in_params[:resource].user_name,
              message: I18n.t('devise.sessions.signed_in')
          })
    end

  end

  # DELETE /security
  def destroy
    authorize! :destroy, :api_security

    if signed_in?
      user_name = current_user.user_name
      sign_out(current_user)
      response_wrapper(
          :ok,
          {
              user_name: user_name,
              message: I18n.t('devise.sessions.signed_out')
          },
          nil,
          [:sign_in, :sign_up])
    else
      response_wrapper(
          :unauthorized,
          nil,
          I18n.t('devise.failure.unauthenticated'),
          [:sign_in, :sign_up])
    end
  end

  private

  def response_wrapper(status_symbol, data, error_details = nil, error_links = [])
    built_response = Settings.api_response.build(status_symbol, data, {error_details: error_details, error_links: error_links})
    render json: built_response, status: status_symbol, layout: false
  end
end