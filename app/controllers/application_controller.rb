class ApplicationController < ActionController::Base

  # userstamp
  include Userstamp

  # error handling for correct route when id does not exist.
  # for incorrect routes see errors_controller and routes.rb
  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found

  protect_from_forgery

  skip_before_filter :verify_authenticity_token, if: :json_request?

  after_filter :set_csrf_cookie_for_ng

  rescue_from CanCan::AccessDenied do |exception|
    if current_user && current_user.confirmed?
      if !request.env["HTTP_REFERER"].blank? and request.env["HTTP_REFERER"] != request.env["REQUEST_URI"]
        respond_to do |format|
          format.html { redirect_to :back, :alert => exception.message }
        end
      else
        respond_to do |format|
          format.html { redirect_to projects_path, :alert => exception.message }
          format.json { render json: {error: exception.message}.to_json, status: :unauthorized }
        end

      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, :alert => exception.message }
        format.json { render json: {error: exception.message}.to_json, status: :unauthorized }
      end
    end
  end

  def add_archived_at_header(model)
    if model.respond_to?(:deleted_at) && !model.deleted_at.blank?
      response.headers['X-Archived-At'] = model.deleted_at
    end
  end

  def no_content_as_json
    head :no_content, :content_type => 'application/json'
  end

  protected

  def json_request?
    request.format.json?
  end

  # http://stackoverflow.com/questions/14734243/rails-csrf-protection-angular-js-protect-from-forgery-makes-me-to-log-out-on
  def set_csrf_cookie_for_ng
    csrf_cookie_key = 'XSRF-TOKEN'
    if request.format.json?
      cookies[csrf_cookie_key] = form_authenticity_token if protect_against_forgery?
    end
  end

  # http://stackoverflow.com/questions/14734243/rails-csrf-protection-angular-js-protect-from-forgery-makes-me-to-log-out-on
  # cookies can only be accessed by js from the same origin (protocol, host and port) as the response.
  # WARNING: disable csrf check for json for now.
  def verified_request?
    if request.format.json?
      true
    else
      csrf_header_key = 'X-XSRF-TOKEN'
      super || form_authenticity_token == request.headers[csrf_header_key]
    end
  end

  private

  def set_stampers
    User.stamper = self.current_user
  end

  # Devise: Overwriting the sign_out redirect path method
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  # Devise: Overwriting the sign_up redirect path method
  def after_sign_up_path_for(resource_or_scope)
    new_user_session_path
  end

  # Devise: Overwriting the sign_up redirect path method
  def after_sign_up_path_for(resource_or_scope)
    projects_path
  end

  def record_not_found(error)
    respond_to do |format|
      format.html { render :template => 'errors/record_not_found', locals: {message: error.message}, status: :not_found }
      format.json { render :json => {error: '404 Not Found', message: error.message}, status: :not_found }
    end
  end


end
