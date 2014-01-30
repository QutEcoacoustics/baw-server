class ApplicationController < ActionController::Base

  # userstamp
  include Userstamp

  # error handling for correct route when id does not exist.
  # for incorrect routes see errors_controller and routes.rb
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordNotUnique, with: :record_not_unique


  protect_from_forgery

  skip_before_filter :verify_authenticity_token, if: :json_request?

  after_filter :set_csrf_cookie_for_ng

  rescue_from CanCan::AccessDenied do |exception|
    if current_user && current_user.confirmed?
      if !request.env["HTTP_REFERER"].blank? and request.env["HTTP_REFERER"] != request.env["REQUEST_URI"]
        respond_to do |format|
          format.html { redirect_to :back, :alert => exception.message }
          format.json { render json: {error: exception.message}.to_json, status: :forbidden }
        end
      else
        respond_to do |format|
          format.html { redirect_to projects_path, :alert => exception.message }
          format.json { render json: {error: exception.message}.to_json, status: :forbidden }
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
    request.format && request.format.json?
  end

  # http://stackoverflow.com/questions/14734243/rails-csrf-protection-angular-js-protect-from-forgery-makes-me-to-log-out-on
  def set_csrf_cookie_for_ng
    csrf_cookie_key = 'XSRF-TOKEN'
    if request.format && request.format.json?
      cookies[csrf_cookie_key] = form_authenticity_token if protect_against_forgery?
    end
  end

  # http://stackoverflow.com/questions/14734243/rails-csrf-protection-angular-js-protect-from-forgery-makes-me-to-log-out-on
  # cookies can only be accessed by js from the same origin (protocol, host and port) as the response.
  # WARNING: disable csrf check for json for now.
  def verified_request?
    if request.format && request.format.json?
      true
    else
      csrf_header_key = 'X-XSRF-TOKEN'
      super || form_authenticity_token == request.headers[csrf_header_key]
    end
  end

  # from http://stackoverflow.com/a/94626
  def render_csv(filename = nil)
    require 'csv'
    filename ||= params[:action]
    filename += '.csv'

    if request.env['HTTP_USER_AGENT'] =~ /msie/i
      headers['Pragma'] = 'public'
      headers['Content-type'] = 'text/plain'
      headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
      headers['Expires'] = '0'
    else
      headers['Content-Type'] ||= 'text/csv'
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
    end

    render layout: false
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
      format.html { render template: 'errors/record_not_found', status: :not_found }
      format.json { render json: {error: '404 Not Found'}, status: :not_found }
    end
  end

  def record_not_unique(error)
    respond_to do |format|
      format.html { render template: 'errors/generic', status: :conflict }
      format.json { render json: {error: '409 Conflict', }, status: :conflict }
    end
  end


end
