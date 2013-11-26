# Handles Restful API Authentication only
# http://www.cocoahunter.com/blog/2013/02/13/restful-api-authentication/
class SessionsController < Devise::SessionsController
  #skip_before_filter  :verify_authenticity_token
  before_filter :authenticate_user!, :except => [:create, :destroy]
  respond_to :json

  def create
    resource = User.find_for_database_authentication(:email => params[:email])
    return invalid_login_attempt unless resource

    if resource.valid_password?(params[:password])
      sign_in(:user, resource)
      resource.ensure_authentication_token!
      render :json=> {:success=>true, :auth_token=>resource.authentication_token, :email=>resource.email}
      return
    end
    invalid_login_attempt
  end

  def destroy
    if current_user.blank?
      render :json=> {:success=>false, :message=>"You were not logged in."}, status: :unprocessable_entity
    else
      current_user.authentication_token = nil
      current_user.save
      render :json=> {:success=>true}
    end
  end

  protected

  def invalid_login_attempt
    render :json=> {:success=>false, :message=>"Error with your login or password"}, :status=>401
  end
end