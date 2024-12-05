# frozen_string_literal: true

class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check only: [:route_error, :uncaught_error, :test_exceptions, :show, :method_not_allowed_error]

  # see application_controller.rb for error handling for specific exceptions.
  # see routes.rb for the catch-all route for routing errors.
  # see application.rb for the exceptions_app settings.

  def show
    error_code_or_id = params[:name]

    status_symbol = :bad_request
    detail_message = 'There was a problem with your request. Perhaps go back and try again?'
    error = nil
    method_name = 'errors_show'
    additional_info = { error_info: { original_http_method: request.method } }

    case error_code_or_id
    when 400, '400', 'bad_request'
      status_symbol = :bad_request
    when 401, '401', 'unauthorized'
      status_symbol = :unauthorized
      detail_message = I18n.t('devise.failure.unauthenticated')
      additional_info[:error_links] = [:sign_in, :sign_up, :confirm]
    when 403, '403', 'forbidden'
      status_symbol = :forbidden
      detail_message = I18n.t('devise.failure.unauthorized')
      additional_info[:error_links] = [:permissions, :confirm]
    when 404, '404', 'not_found'
      status_symbol = :not_found
      detail_message = 'Could not find the requested page.'
    when 405, '405', 'method_not_allowed'
      status_symbol = :method_not_allowed
      detail_message = 'HTTP method not allowed for this resource.'
    when 406, '406', 'not_acceptable'
      status_symbol = :not_acceptable
      detail_message = 'We cold not provide the format you asked for. Perhaps try a different file extension?'
      additional_info[:error_info][:available_formats] = Settings.supported_media_types
    when 409, '409', 'conflict'
      status_symbol = :conflict
      detail_message = 'There was a conflict in the request. This could be due to duplicate ' \
                       'items that need to be unique or multiple edits at the same time.'
    when 410, '410', 'gone'
      status_symbol = :gone
      detail_message = 'This content is no longer available.'
    when 415, '415', 'unsupported_media_type'
      status_symbol = :unsupported_media_type
      detail_message = 'The format of your request is not supported. Perhaps try a different format?'
      additional_info[:error_info][:available_formats] = Settings.supported_media_types
    when 416, '416', 'range_not_satisfiable'
      status_symbol = :range_not_satisfiable
      detail_message = 'That range is not available. Check that the range is within the file.'
    when 429, '429', 'too_many_requests'
      status_symbol = :too_many_requests
      detail_message = "There have been too many requests. Take it easy, we're doing our best here."
    end

    render_error(status_symbol, detail_message, error, method_name, additional_info)
  end

  # invoked by the catch-all route in routes.rb
  def route_error
    render_error(
      :not_found,
      'Could not find the requested page.',
      nil,
      'route_error',
      {
        error_info: {
          original_route: params[:requested_route],
          original_http_method: request.method
        }
      }
    )
  end

  def method_not_allowed_error
    render_error(
      :method_not_allowed,
      'HTTP method not allowed for this resource.',
      nil,
      'method_not_allowed_error',
      {
        error_info: {
          original_route: params[:requested_route],
          original_http_method: request.method
        }
      }
    )
  end

  # invoked by the exceptions_app setting in application.rb
  def uncaught_error
    # called with env as a parameter

    # http://geekmonkey.org/articles/29-exception-applications-in-rails-3-2
    # for friendly responses to exceptions
    # only used when:
    # Rails.application.config.consider_all_requests_local = false
    # Rails.application.config.action_dispatch.show_exceptions = :all
    # https://github.com/s-andringa/recipes_exceptions_example/blob/b28b42f2b96c808bde93badbb05aff0bdc2c7fe9/app/controllers/exception_controller.rb
    error = request.env['action_dispatch.exception']
    exception_wrapper = ActionDispatch::ExceptionWrapper.new(request.env, error)
    status_code = exception_wrapper.status_code
    rescue_response = exception_wrapper.rescue_responses[error.class.name]
    #rescue_template = exception_wrapper.rescue_template[error.class.name]
    detail_message = Rack::Utils::HTTP_STATUS_CODES[status_code].humanize
    #error_name = error.class.name.titleize
    #error_message = error.message.underscore.humanize

    # give basic information about the error
    # do not reveal information about the error
    render_error(
      rescue_response,
      detail_message,
      error,
      'uncaught_error'
    )

    # I18n.with_options scope: [:exception, :show, rescue_response], exception_name: error.class.name, exception_message: error.message do |i18n|
    #   code = status_code
    #
    #   name = i18n.t "#{error.class.name.underscore}.title", default: i18n.t(:title, default: error.class.name)
    #   message = i18n.t "#{error.class.name.underscore}.description", default: i18n.t(:description, default: error.message)
    # end
  end

  def test_exceptions
    return unless BawApp.test? && params.include?(:exception_class)

    msg = 'Purposeful exception raised for testing.'
    error_class_string = params[:exception_class]

    # Unsafe reflection method constantize called with parameter value.
    # I think this is ok as it's only available in test env.
    error_class = error_class_string.constantize

    case error_class_string
    when 'ActionController::BadRequest'
      raise error_class, response

    when 'ActiveRecord::RecordNotUnique'
      raise error_class, msg

    when 'CustomErrors::UnsupportedMediaTypeError',
          'CustomErrors::NotAcceptableError'
      raise error_class.new(msg, Settings.supported_media_types)
    else
      raise error_class, msg
    end
  end
end
