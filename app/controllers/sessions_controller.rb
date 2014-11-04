# Handles Restful API Authentication only
# @see http://www.cocoahunter.com/blog/2013/02/13/restful-api-authentication/
class SessionsController < Devise::SessionsController
  include Api::ApiAuth

  # custom user authentication
  before_filter :authenticate_user_custom!, except: [:create]

  # This is Devise's authentication
  before_filter :authenticate_user!

  # remove Devise's default destroy response
  skip_before_filter :verify_signed_out_user

  skip_before_filter :verify_authenticity_token, if: :json_request?

  check_authorization except: [:create]

  respond_to :json

  def show_custom
    authorize! :show, :api_security

    if signed_in?
      response_wrapper(
          :ok,
          {
              auth_token:  current_user.authentication_token,
              email: current_user.email,
              user_name: current_user.user_name
          })
      else
      response_wrapper(
          :unauthorized,
          nil,
          'You were not logged in.',
          [:sign_in, :sign_up])
    end
  end

  # Request to log in.
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
              email: sign_in_params[:resource].email,
              user_name: sign_in_params[:resource].user_name
          },
          'You have been signed in.')
    end

  end

  def destroy
    authorize! :destroy, :api_security

    if signed_in?
      sign_out(current_user)
      response_wrapper(
          :ok,
          nil,
          'You have been signed out.',
          [:sign_in, :sign_up])
      else
      response_wrapper(
          :unprocessable_entity,
          nil,
          'You were not logged in, so you cannot sign out.',
          [:sign_in, :sign_up])
    end
  end

  private

  def response_wrapper(status_symbol, data, error_details = nil, error_links = [])
    built_response = Settings.api_response.build(status_symbol, data, {error_details: error_details, error_links: error_links})
    render json: built_response, status: status_symbol, layout: false
  end
end