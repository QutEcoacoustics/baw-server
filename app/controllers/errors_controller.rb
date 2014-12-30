class ErrorsController < ApplicationController

  skip_authorization_check only: [:route_error, :uncaught_error]

  # see application_controller.rb for error handling for specific exceptions.
  # see routes.rb for the catch-all route for routing errors.
  # see application.rb for the exceptions_app settings.


  def route_error

    render_error(
        :not_found,
        'Could not find the requested page.',
        nil,
        'route_error',
        error_info: {original_route: params[:requested_route], original_http_method: request.method}
    )

  end


  def uncaught_error

    # called with env as a parameter

    # http://geekmonkey.org/articles/29-exception-applications-in-rails-3-2
    # for friendly responses to exceptions
    # only used when:
    # Rails.application.config.consider_all_requests_local = false
    # Rails.application.config.action_dispatch.show_exceptions = true
    # https://github.com/s-andringa/recipes_exceptions_example/blob/b28b42f2b96c808bde93badbb05aff0bdc2c7fe9/app/controllers/exception_controller.rb

    error = env['action_dispatch.exception']
    exception_wrapper = ActionDispatch::ExceptionWrapper.new(env, error)
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


end