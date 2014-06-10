class ApplicationController < ActionController::Base
# CanCan - always check authorization
  check_authorization unless: :devise_controller?

  # userstamp
  include Userstamp

  # error handling for correct route when id does not exist.
  # for incorrect routes see errors_controller and routes.rb
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordNotUnique, with: :record_not_unique

  # error handling for cancan authorisation checks
  rescue_from CanCan::AccessDenied, with: :access_denied

  # error handling for routes that take a combination of attributes
  rescue_from CustomErrors::RoutingArgumentError, with: :routing_argument_missing

  protect_from_forgery

  skip_before_filter :verify_authenticity_token, if: :json_request?

  after_filter :set_csrf_cookie_for_ng, :resource_representation_caching_fixes

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
    filename = filename.trim('.', '')
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

  def record_not_found(error)
    respond_to do |format|
      format.html { render template: 'errors/record_not_found', status: :not_found }
      format.json { render json: {code: 404, phrase: 'Not Found', message: 'Not found'}, status: :not_found }
      format.all { render json: {code: 404, phrase: 'Not Found', message: 'Not found'}, status: :not_found }
    end
  end

  def record_not_unique(error)
    respond_to do |format|
      format.html { render template: 'errors/generic', status: :conflict }
      format.json { render json: {code: 409, phrase: 'Conflict', message: 'Not unique'}, status: :conflict }
      format.all { render json: {code: 409, phrase: 'Conflict', message: 'Not unique'}, status: :conflict }
    end
  end

  def access_denied(error)
    if current_user && current_user.confirmed?

      msg_forbidden = I18n.t 'devise.failure.unauthorized'
      json_forbidden = {
          code: 403,
          phrase: 'Forbidden',
          message: msg_forbidden,
          request_new_permissions_link: new_access_request_projects_url
      }

      if !request.env['HTTP_REFERER'].blank? and request.env['HTTP_REFERER'] != request.env['REQUEST_URI']
        respond_to do |format|
          format.html { redirect_to :back, alert: msg_forbidden }
          format.json { render json: json_forbidden.to_json, status: :forbidden }
          format.all { render json: json_forbidden.to_json, status: :forbidden, content_type: 'application/json' }
        end
      else
        respond_to do |format|
          format.html { redirect_to projects_path, alert: msg_forbidden }
          format.json { render json: json_forbidden.to_json, status: :forbidden }
          format.all { render json: json_forbidden.to_json, status: :forbidden, content_type: 'application/json' }
        end

      end
    else

      msg_response = I18n.t 'devise.failure.unauthenticated'
      json_response = {
          code: 401,
          phrase: 'Unauthorized',
          message: msg_response,
          sign_in_link: new_user_session_url,
          user_confirmation_link: new_user_confirmation_url
      }.to_json

      # http://blogs.thewehners.net/josh/posts/354-obscure-rails-bug-respond_to-formatany
      respond_to do |format|
        format.html { redirect_to root_path, alert: msg_response }
        format.json { render json: json_response, status: :unauthorized }
        format.all { render json: json_response, status: :unauthorized, content_type: 'application/json' }
      end
    end
  end

  def routing_argument_missing(error)
    msg = 'Bad request, please change the request and try again.'
    json_response = {
        code: 400,
        phrase: 'Bad Request',
        message: msg
    }.to_json

    respond_to do |format|
      format.html { redirect_to root_path, alert: msg }
      format.json { render json: json_response, status: :bad_request }
      format.all { render json: json_response, status: :bad_request, content_type: 'application/json' }
    end
  end

  def resource_representation_caching_fixes
    # send Vary: Accept for all text/html and application/json responses
    if response.content_type == 'text/html' || response.content_type == 'application/json'
      response.headers['Vary'] = 'Accept'
    end
  end

end
