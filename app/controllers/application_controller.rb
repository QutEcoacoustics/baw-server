class ApplicationController < ActionController::Base
  layout :api_or_html

  # CanCan - always check authorization
  check_authorization unless: :devise_controller?

  # userstamp
  include Userstamp

  # error handling for correct route when id does not exist.
  # for incorrect routes see errors_controller and routes.rb
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_error
  rescue_from CustomErrors::ItemNotFoundError, with: :resource_not_found_error
  rescue_from ActiveRecord::RecordNotUnique, with: :record_not_unique_error
  rescue_from CustomErrors::UnsupportedMediaTypeError, with: :unsupported_media_type_error
  rescue_from CustomErrors::UnprocessableEntityError, with: :unprocessable_entity_error
  rescue_from ActiveResource::BadRequest, with: :bad_request

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

  def auth_custom_audio_recording(request_params)
    # do auth manually
    #authorize! :show, @audio_recording

    audio_recording = AudioRecording.where(id: request_params[:audio_recording_id]).first
    fail ActiveRecord::RecordNotFound, 'Could not find audio recording with given id.' if audio_recording.blank?

    # can? should also check for admin access
    can_access_audio_recording = can? :show, audio_recording

    # Can't do anything if can't access audio recording and no audio event id given
    fail CanCan::AccessDenied, 'Permission denied to audio recording and no audio event id given.' if !can_access_audio_recording && request_params[:audio_event_id].blank?

    audio_recording
  end

  def auth_custom_audio_event(request_params, audio_recording)
    audio_event = AudioEvent.where(id: request_params[:audio_event_id]).first
    fail ActiveRecord::RecordNotFound, 'Could not find audio event with given id.' if audio_event.blank?

    # can? should also check for admin access
    can_access_audio_event = can? :read, audio_event
    fail CanCan::AccessDenied, "Requested audio event (#{audio_event.audio_recording_id}) and audio recording (#{audio_recording.id}) must be related." if audio_event.audio_recording_id != audio_recording.id
    fail CanCan::AccessDenied, 'Permission denied to audio event, and it is not a marked as reference.' if !audio_event.is_reference && !can_access_audio_event
    audio_event
  end

  def create_json_data_response(status_symbol, data)
    json_response = create_json_response(status_symbol)

    json_response[:data] = data

    json_response
  end

  private

  def record_not_found_error(error)

    render_error(
        :not_found,
        'Not found',
        error,
        'record_not_found_error',
        nil,
        'errors/record_not_found'
    )

    check_reset_stamper
  end

  def resource_not_found_error(error)
    # #render json: {code: 404, phrase: 'Not Found', message: 'Audio recording is not ready'}, status: :not_found
    render_error(
        :not_found,
        error.message,
        error,
        'resource_not_found_error',
        nil,
        'errors/record_not_found'
    )

    check_reset_stamper
  end


  def record_not_unique_error(error)

    render_error(
        :conflict,
        'Not unique',
        error,
        'record_not_unique_error',
        nil,
        'errors/generic'
    )

    check_reset_stamper
  end

  def unsupported_media_type_error(error)
    # render json: {code: 415, phrase: 'Unsupported Media Type', message: 'Requested format is invalid. It must be one of available_formats.', available_formats: @available_formats}, status: :unsupported_media_type

    render_error(
        :unsupported_media_type,
        error.message,
        error,
        'unsupported_media_type_error',
        nil,
        'errors/generic'
    )

    check_reset_stamper
  end

  def unprocessable_entity_error(error)
    render_error(
        :unprocessable_entity,
        error.message,
        error,
        'unsupported_media_type',
        nil,
        'errors/generic'
    )

    check_reset_stamper
  end

  def bad_request(error)
    # render json: {code: 400, phrase: 'Bad Request', message: 'Invalid request'}, status: :bad_request

    render_error(
        :bad_request,
        'Invalid request',
        error,
        'bad_request',
        nil,
        'errors/generic'
    )

    check_reset_stamper
  end

  def access_denied(error)
    if current_user && current_user.confirmed?
      render_error(:forbidden, I18n.t('devise.failure.unauthorized'), error, 'access_denied - forbidden', [:permissions])

    elsif current_user && !current_user.confirmed?
      render_error(:forbidden, I18n.t('devise.failure.unconfirmed'), error, 'access_denied - unconfirmed', [:confirm])

    else
      render_error(:unauthorized, I18n.t('devise.failure.unauthenticated'), error, 'access_denied - unauthorised', [:sign_in, :confirm])

    end

    check_reset_stamper
  end

  def routing_argument_missing(error)

    render_error(
        :bad_request,
        'Bad request, please change the request and try again.',
        error,
        'routing_argument_missing'
    )

    check_reset_stamper
  end

  def resource_representation_caching_fixes
    # send Vary: Accept for all text/html and application/json responses
    if response.content_type == 'text/html' || response.content_type == 'application/json'
      response.headers['Vary'] = 'Accept'
    end
  end

  def check_reset_stamper
    reset_stamper if User.stamper
  end

  def log_original_error(method_name, error, response_given)
    Rails.logger.warn "Error handled by #{method_name} in application controller. Original error: #{error.inspect}. Response given: #{response_given}."
  end

  def api_or_html
    if json_request?
      'api'
    else
      'application'
    end
  end

  def render_error(status_symbol, detail_message, error, method_name, links_object = nil, template = nil)

    json_response = create_json_error_response(status_symbol, detail_message, links_object)

    # method_name = __method__
    # caller[0]
    log_original_error(method_name, error, json_response)

    respond_to do |format|
      format.html {
        default_template = 'errors/generic'
        if template.blank?
          redirect_to get_redirect, alert: detail_message
        else
          render template: template, status: status_symbol
        end
      }
      format.json { render json: json_response, status: status_symbol }
      # http://blogs.thewehners.net/josh/posts/354-obscure-rails-bug-respond_to-formatany
      format.all { render json: json_response, status: status_symbol, content_type: 'application/json' }
    end

  end

  def get_redirect
    if !request.env['HTTP_REFERER'].blank? and request.env['HTTP_REFERER'] != request.env['REQUEST_URI']
      redirect_target = :back
    else
      redirect_target = root_path
    end

    redirect_target
  end

  def create_json_response(status_symbol)
    status_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status_symbol]
    status_message = Rack::Utils::HTTP_STATUS_CODES[status_code]

    json_response = {
        meta: {
            status: status_code,
            message: status_message
        },
        data: nil
    }

    json_response
  end

  def create_json_error_response(status_symbol, detail_message, links_object = nil)
    json_response = create_json_response(status_symbol)

    json_response[:meta][:error] = {} if !detail_message.blank? && !links_object.blank?

    json_response[:meta][:error][:details] = detail_message unless detail_message.blank?

    json_response[:meta][:error][:links] = {} unless links_object.blank?
    json_response[:meta][:error][:links]['sign in'] = new_user_session_url if !links_object.blank? && links_object.include?(:sign_in)
    json_response[:meta][:error][:links]['request permissions'] = new_access_request_projects_url if !links_object.blank? && links_object.include?(:permissions)
    json_response[:meta][:error][:links]['confirm your account'] = new_user_confirmation_url if !links_object.blank? && links_object.include?(:confirm)

    json_response
  end

end
