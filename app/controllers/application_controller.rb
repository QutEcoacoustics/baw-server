class ApplicationController < ActionController::Base
  include Api::ApiAuth

  layout :select_layout

  # custom authentication for api only
  before_action :authenticate_user_custom!

  # devise strong params set up
  before_action :configure_permitted_parameters, if: :devise_controller?

  # https://github.com/plataformatec/devise/blob/master/test/rails_app/app/controllers/application_controller.rb
  # devise's generated methods
  before_action :current_user, unless: :devise_controller?
  before_action :authenticate_user!, if: :devise_controller?

  # CanCan - always check authorization
  check_authorization if: :should_check_authorization?

  # see routes.rb for the catch-all route for routing errors.
  # see application.rb for the exceptions_app settings.
  # see errors_controller.rb for the actions that handle routing errors and uncaught errors.

  # Ruby and Rails errors - do not reveal information about the error
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_response
  rescue_from ActiveRecord::RecordNotUnique, with: :record_not_unique_response
  rescue_from ActionController::BadRequest, with: :bad_request_response
  rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_csrf_response
  rescue_from NotImplementedError, with: :not_implemented_response

  # Custom errors - these use the message in the error
  # RoutingArgumentError - error handling for routes that take a combination of attributes
  rescue_from CustomErrors::RoutingArgumentError, with: :routing_argument_error_response
  rescue_from CustomErrors::ItemNotFoundError, with: :item_not_found_error_response
  rescue_from CustomErrors::UnsupportedMediaTypeError, with: :unsupported_media_type_error_response
  rescue_from CustomErrors::MethodNotAllowedError, with: :method_not_allowed_error_response
  rescue_from CustomErrors::NotAcceptableError, with: :not_acceptable_error_response
  rescue_from CustomErrors::UnprocessableEntityError, with: :unprocessable_entity_error_response
  rescue_from CustomErrors::FilterArgumentError, with: :filter_argument_error_response
  rescue_from CustomErrors::AudioGenerationError, with: :audio_generation_error_response
  rescue_from BawAudioTools::Exceptions::AudioToolError, with: :audio_tool_error_response

  # Don't rescue this, it is the base for 406 and 415
  #rescue_from CustomErrors::RequestedMediaTypeError, with: :requested_media_type_error_response

  rescue_from CustomErrors::BadRequestError, with: :bad_request_error_response

  # error handling for cancan authorisation checks
  rescue_from CanCan::AccessDenied, with: :access_denied_response

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # for responses, ensure CSRF cookie is set and fix problems with Vary header
  after_action :set_csrf_cookie, :resource_representation_caching_fixes

  # set and reset user stamper for each request
  # based on https://github.com/theepan/userstamp/tree/bf05d832ee27a717ea9455d685c83ae2cfb80310
  around_action :set_then_reset_user_stamper

  # update users last activity log every 10 minutes
  before_action :set_last_seen_at,
                if: Proc.new { user_signed_in? &&
                    (session[:last_seen_at].blank? || Time.zone.at(session[:last_seen_at].to_i) < 10.minutes.ago)
                }

  protected

  def add_archived_at_header(model)
    if model.respond_to?(:deleted_at) && !model.deleted_at.blank?
      response.headers['X-Archived-At'] = model.deleted_at.httpdate # must be a string, can't just pass a Date or Time
    end
  end

  def add_header_length(length)
    response.headers['Content-Length'] = length.to_s
  end

  def no_content_as_json
    head :no_content, :content_type => 'application/json'
  end

  def json_request?
    request.format && request.format.json?
  end

  # CSRF protection is enabled for API.
  # This enforces login via the UI only, since requests without a logged in user won't have access to the CSRF cookie.
  def verified_request?
    csrf_header_key = 'X-XSRF-TOKEN'
    super || valid_authenticity_token?(session, request.headers[csrf_header_key]) || api_auth_success?
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
    can_access_audio_event = can? :show, audio_event
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
    options.merge!(error_details: detail_message) # overwrites error_details
    options.reverse_merge!(should_notify_error: true) # default for should_notify_error is true, value in options will overwrite

    # notify of exception when head requests AND when should_notify_error is true
    should_notify_error = request.head? && (options.include?(:should_notify_error) && options[:should_notify_error])

    json_response = Settings.api_response.build(status_symbol, nil, options)

    if should_notify_error
      ExceptionNotifier.notify_exception(
          error,
          env: request.env,
          data: {
              method_name: method_name,
              json_response: json_response
          })
    end

    # method_name = __method__
    # caller[0]
    log_original_error(method_name, error, json_response)

    # add custom header
    headers['X-Error-Type'] = error.class.to_s.titleize unless error.nil?

    respond_to do |format|
      # format.all will be used for Accept: */* as it is first in the list
      # http://blogs.thewehners.net/josh/posts/354-obscure-rails-bug-respond_to-formatany
      format.all {
        actual_format = request.format.to_s

        if actual_format.start_with?('audio') || actual_format.start_with?('image')
          headers['Accept-Ranges'] = 'bytes'
          head status_symbol
        else
          render json: json_response, status: status_symbol, content_type: 'application/json'
        end
      }
      format.json {
        render json: json_response, status: status_symbol
      }
      format.html {

        status_code = Settings.api_response.status_code(status_symbol)
        status_message = Settings.api_response.status_phrase(status_symbol).humanize

        response_links = Settings.api_response.response_error_links(options[:error_links])

        @details = {
            code: status_code,
            phrase: status_message,
            message: detail_message,
            links: response_links,
            supported_media: []
        }

        if options[:error_info] && options[:error_info][:available_formats]
          @details[:supported_media] = options[:error_info][:available_formats]
        end

        # get a redirect path
        redirect_to = params[:redirect_to] || request.fullpath || request.path || nil

        if redirect_to

          # store the path where the cancan error was thrown
          # devise will redirect to this when the user signs in
          store_location_for(:user, redirect_to)

          # use stored_location_for to ensure the redirect is safe (i.e. doesn't go to another website)
          @details[:redirect_to_url] = stored_location_for(:user)
        end


        render template: 'errors/generic', status: status_symbol
      }
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:user_name, :email, :password, :password_confirmation) }
    devise_parameter_sanitizer.for(:account_update) { |u| u.permit(:user_name, :email, :password, :password_confirmation, :current_password, :image, :tzinfo_tz) }
  end

  def after_sign_in_path_for(resource)
    super
  end

  def store_location(path)
    super
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
        'item_not_found_error_response',
        {should_notify_error: false}
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
        {error_info: {available_formats: error.available_formats_info}}
    )
  end

  def method_not_allowed_error_response(error)
    # 405 - Method Not Allowed
    # We don't allow that verb, for that request

    request.format = :json

    render_error(
        :method_not_allowed,
        "The method received the request is known by the server but not supported by the target resource: #{error.message}",
        error,
        'method_not_allowed_error_response',
        {error_info: {available_methods: error.available_methods.map { |x| x.to_s.upcase }}}
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
        {error_info: {available_formats: error.available_formats_info}}
    )
  end

  def unprocessable_entity_error_response(error)
    options = error.additional_details.nil? ? {} : {error_info: error.additional_details}
    render_error(
        :unprocessable_entity,
        "The request could not be understood: #{error.message}",
        error,
        'unprocessable_entity_error_response',
        options
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

  def invalid_csrf_response(error)
    render_error(
        :bad_request,
        'The request could not be verified.',
        error,
        'invalid_csrf_response',
    )
  end

  def access_denied_response(error)
    if current_user && current_user.confirmed?
      render_error(
          :forbidden,
          I18n.t('devise.failure.unauthorized'),
          error,
          'access_denied_response - forbidden',
          {error_links: [:permissions]})

    elsif current_user && !current_user.confirmed?
      render_error(
          :forbidden,
          I18n.t('devise.failure.unconfirmed'),
          error,
          'access_denied_response - unconfirmed',
          {error_links: [:confirm]})

    else

      render_error(
          :unauthorized,
          I18n.t('devise.failure.unauthenticated'),
          error,
          'access_denied_response - unauthorised',
          {error_links: [:sign_in, :sign_up, :confirm]})

    end
  end

  def routing_argument_error_response(error)
    render_error(
        :not_found,
        "Could not find the requested page: #{error.message}",
        error,
        'routing_argument_error_response',
        {error_info: {original_route: request.env['PATH_INFO'], original_http_method: request.method}}
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

  def filter_argument_error_response(error)
    render_error(
        :bad_request,
        "Filter parameters were not valid: #{error.message}",
        error,
        'filter_argument_error_response',
        {error_info: error.filter_segment}
    )
  end

  def audio_generation_error_response(error)
    render_error(
        :internal_server_error,
        "Audio generation failed: #{error.message}",
        error,
        'audio_generation_error_response',
        {error_info: error.job_info}
    )
  end

  def audio_tool_error_response(error)
    render_error(
        :internal_server_error,
        "Audio generation failed: #{error.message}",
        error,
        'audio_tool_error_response'
    )
  end

  def not_implemented_response(error)
    render_error(
        :not_implemented,
        'The service is not ready for use',
        error,
        'not_implemented_response'
    )
  end

  def resource_representation_caching_fixes
    # send Vary: Accept for all text/html and application/json responses
    if response.content_type == 'text/html' || response.content_type == 'application/json'
      response.headers['Vary'] = 'Accept'
    end
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

  def select_layout
    if json_request?
      'api'
    else
      'application'
    end
  end

  def set_then_reset_user_stamper
    begin
      # TODO: this causes a deprecation warning if nil is
      # given to Devise::Strategies::DatabaseAuthenticatable#validate
      User.stamper = self.current_user
      yield
    ensure
      User.stamper = nil
    end
  end

  def set_last_seen_at
    the_time = Time.zone.now
    current_user.update_attribute(:last_seen_at, the_time)
    session[:last_seen_at] = the_time.to_i
  end

  def should_check_authorization?
    is_devise_controller = devise_controller?
    is_admin_controller = respond_to?(:admin_controller?) && admin_controller?

    !is_devise_controller && !is_admin_controller
  end

end
