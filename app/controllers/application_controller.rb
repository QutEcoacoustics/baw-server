class ApplicationController < ActionController::Base
  layout :api_or_html

  # CanCan - always check authorization
  check_authorization unless: :devise_controller?

  # userstamp
  include Userstamp

  # see routes.rb for the catch-all route for routing errors.
  # see application.rb for the exceptions_app settings.
  # see errors_controller.rb for the actions that handle routing errors and uncaught errors.

  # Ruby and Rails errors - do not reveal information about the error
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_response
  rescue_from ActiveRecord::RecordNotUnique, with: :record_not_unique_response
  rescue_from ActiveResource::BadRequest, with: :bad_request_response

  # Custom errors - these use the message in the error
  # RoutingArgumentError - error handling for routes that take a combination of attributes
  rescue_from CustomErrors::RoutingArgumentError, with: :routing_argument_error_response
  rescue_from CustomErrors::ItemNotFoundError, with: :item_not_found_error_response
  rescue_from CustomErrors::UnsupportedMediaTypeError, with: :unsupported_media_type_error_response
  rescue_from CustomErrors::NotAcceptableError, with: :not_acceptable_error_response
  rescue_from CustomErrors::UnprocessableEntityError, with: :unprocessable_entity_error_response

  # Don't rescue this, it is the base for 406 and 415
  #rescue_from CustomErrors::RequestedMediaTypeError, with: :requested_media_type_error_response

  rescue_from CustomErrors::BadRequestError, with: :bad_request_error_response

  # error handling for cancan authorisation checks
  rescue_from CanCan::AccessDenied, with: :access_denied_response

  protect_from_forgery

  skip_before_filter :verify_authenticity_token, if: :json_request?

  after_filter :set_csrf_cookie_for_ng, :resource_representation_caching_fixes

  protected

  def add_archived_at_header(model)
    if model.respond_to?(:deleted_at) && !model.deleted_at.blank?
      response.headers['X-Archived-At'] = model.deleted_at
    end
  end

  def no_content_as_json
    head :no_content, :content_type => 'application/json'
  end

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
    fail CustomErrors::ItemNotFoundError, "Could not find audio recording with id #{request_params[:audio_recording_id]}." if audio_recording.blank?

    # can? also checks for admin access
    can_access_audio_recording = can? :show, audio_recording

    # Can't do anything if can't access audio recording and no audio event id given
    has_any_permission = can_access_audio_recording || !request_params[:audio_event_id].blank?
    fail CanCan::AccessDenied, "Permission denied to audio recording id #{request_params[:audio_recording_id]} and no audio event id given." unless has_any_permission

    audio_recording
  end

  def auth_custom_audio_event(request_params, audio_recording)
    audio_event = AudioEvent.where(id: request_params[:audio_event_id]).first
    fail CustomErrors::ItemNotFoundError, "Could not find audio event with id #{request_params[:audio_event_id]}." if audio_event.blank?

    # can? also checks for admin access
    can_access_audio_event = can? :read, audio_event
    matching_ids = audio_event.audio_recording_id == audio_recording.id
    is_reference = audio_event.is_reference
    has_any_permission = can_access_audio_event || is_reference

    unless matching_ids
      msg = "Requested audio event (#{audio_event.audio_recording_id}) " +
          "and audio recording (#{audio_recording.id}) must be related."
      fail CanCan::AccessDenied, msg
    end

    unless has_any_permission
      msg = "Permission denied to audio event (#{audio_event.id})"+
          'and it is not a marked as reference.'
      fail CanCan::AccessDenied, msg
    end

    audio_event
  end

  def auth_custom_offsets(request_params, audio_recording, audio_event)
    # check offsets are within range

    start_offset = 0.0
    start_offset = request_params[:start_offset].to_f if request_params.include?(:start_offset)

    end_offset = audio_recording.duration_seconds.to_f
    end_offset = request_params[:end_offset].to_f if request_params.include?(:end_offset)

    audio_event_start = audio_event.start_time_seconds
    audio_event_end = audio_event.end_time_seconds

    allowable_padding = 5

    allowable_start_offset = audio_event_start - allowable_padding
    allowable_end_offset = audio_event_end + allowable_padding

    msg1 = "Permission denied to audio recording (#{audio_recording.id}): "
    msg3 = "(including padding of #{allowable_padding})."

    if start_offset < allowable_start_offset
      msg2 = "start offset (#{start_offset}) was less than allowable bounds (#{allowable_start_offset}) "
      fail CanCan::AccessDenied, msg1 + msg2 + msg3
    end

    if end_offset > allowable_end_offset
      msg2 = "end offset (#{end_offset}) was greater than allowable bounds (#{allowable_end_offset}) "
      fail CanCan::AccessDenied, msg1 + msg2 + msg3
    end

  end

  def render_error(status_symbol, detail_message, error, method_name, options = {})
    options = {redirect: false, links_object: nil, error_info: nil}.merge(options)

    json_response = api_response.response_error(status_symbol, detail_message, options[:links_object])

    unless options[:error_info].blank?
      json_response.meta.error.merge!(options[:error_info])
    end

    # method_name = __method__
    # caller[0]
    log_original_error(method_name, error, json_response)

    respond_to do |format|
      format.html {

        status_code = api_response.status_code(status_symbol)
        status_message = api_response.status_phrase(status_symbol).humanize

        response_links = api_response.response_links(options[:links_object])

        if options[:redirect]
          redirect_to get_redirect, alert: "#{status_message}: #{detail_message}"
        else
          @details = {code: status_code, phrase: status_message, message: detail_message, links: response_links}
          render template: 'errors/generic', status: status_symbol
        end
      }
      format.json { render json: json_response, status: status_symbol }
      # http://blogs.thewehners.net/josh/posts/354-obscure-rails-bug-respond_to-formatany
      format.all { render json: json_response, status: status_symbol, content_type: 'application/json' }
    end

    check_reset_stamper
  end

  def render_api_response(content, status_symbol = :ok)
    respond_to do |format|
      format.all { render json: content, status: status_symbol, content_type: 'application/json' }
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

  def api_response
    @api_response ||= Api::Response.new
  end

  private

  def record_not_found_response(error)

    render_error(
        :not_found,
        'Could not find the requested item.',
        error,
        'record_not_found_response'
    )
  end

  def item_not_found_error_response(error)
    # #render json: {code: 404, phrase: 'Not Found', message: 'Audio recording is not ready'}, status: :not_found
    render_error(
        :not_found,
        "Could not find the requested item: #{error.message}",
        error,
        'item_not_found_error_response'
    )
  end


  def record_not_unique_response(error)

    render_error(
        :conflict,
        'The item must be unique.',
        error,
        'record_not_unique_response'
    )
  end

  def unsupported_media_type_error_response(error)
    # 415 - Unsupported Media Type
    # they sent what we don't want
    # render json: {code: 415, phrase: 'Unsupported Media Type', message: 'Requested format is invalid. It must be one of available_formats.', available_formats: @available_formats}, status: :unsupported_media_type

    render_error(
        :unsupported_media_type,
        "The format of the request is not supported: #{error.message}",
        error,
        'unsupported_media_type_error_response',
        error_info: {available_formats: error.available_formats_info}
    )
  end

  def not_acceptable_error_response(error)
    # 406 - Not Acceptable
    # we can't send what they want

    request.format = :json

    render_error(
        :not_acceptable,
        "None of the acceptable response formats are available: #{error.message}",
        error,
        'not_acceptable_error_response',
        error_info: {available_formats: error.available_formats_info}
    )
  end

  def unprocessable_entity_error_response(error)
    render_error(
        :unprocessable_entity,
        "The request could not be understood: #{error.message}",
        error,
        'unprocessable_entity_error_response'
    )
  end

  def bad_request_response(error)
    # render json: {code: 400, phrase: 'Bad Request', message: 'Invalid request'}, status: :bad_request

    render_error(
        :bad_request,
        'The request was not valid.',
        error,
        'bad_request_response',
    )
  end

  def access_denied_response(error)
    if current_user && current_user.confirmed?
      render_error(
          :forbidden,
          I18n.t('devise.failure.unauthorized'),
          error,
          'access_denied_response - forbidden',
          redirect: false,
          links_object: [:permissions])

    elsif current_user && !current_user.confirmed?
      render_error(
          :forbidden,
          I18n.t('devise.failure.unconfirmed'),
          error,
          'access_denied_response - unconfirmed',
          redirect: false,
          links_object: [:confirm])

    else
      render_error(
          :unauthorized,
          I18n.t('devise.failure.unauthenticated'),
          error,
          'access_denied_response - unauthorised',
          redirect: false,
          links_object: [:sign_in, :confirm])

    end
  end

  def routing_argument_error_response(error)
    render_error(
        :not_found,
        "Could not find the requested page: #{error.message}",
        error,
        'routing_argument_error_response',
        error_info: {original_route: request.env['PATH_INFO']}
    )
  end

  def bad_request_error_response(error)
    render_error(
        :bad_request,
        "The request was not valid: #{error.message}",
        error,
        'bad_request_error_response',
    )
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

    msg = "Error handled by #{method_name} in application or errors controller."

    if error.blank?
      msg += ' No original error.'
    else
      msg += " Original error: #{error.inspect}."
    end

    msg += " Response given: #{response_given}."

    Rails.logger.warn msg
  end

  def api_or_html
    if json_request?
      'api'
    else
      'application'
    end
  end

end
