# frozen_string_literal: true

# Base controller for our application (including legacy support for views/non-API responses)
class ApplicationController < ActionController::Base
  include Api::ApiAuth
  include Api::DirectoryRenderer
  include Api::Actions::Invocable
  include Api::Archivable

  include IncludeController

  include ActiveStorage::SetCurrent
  include SetCurrent

  # https://github.com/plataformatec/devise/blob/master/test/rails_app/app/controllers/application_controller.rb
  # devise's generated methods
  # Note: we define our own authenticate_user! method in Api::ApiAuth
  # See `should_authenticate_user?` method below for logic.
  before_action :authenticate_user!

  # CanCan - always check authorization
  check_authorization if: :should_check_authorization?

  layout :select_layout

  def default_url_options
    # see https://edgeguides.rubyonrails.org/action_controller_overview.html#default-url-options
    {
      host: Settings.host.name,
      protocol: BawApp.http_scheme,
      port: Settings.host.port
    }
  end

  def select_layout
    if json_request?
      'api'
    else
      'application'
    end
  end

  # The current action as a symbol
  # @return [Symbol]
  def action_sym
    @action_sym ||= action_name.to_sym
  end

  # OK our general auth strategy is:
  # - dangerous actions (:create, :update, :destroy) trigger authentication here
  #   which will shortcut fail on lack of authentication with this filter.
  # - idempotent actions (:index, :filter, :new, :show) are generally accessible
  #   anonymously and thus will not trigger authentication. Generally these actions
  #   should always be anonymously accessible but should correctly omit any
  #   items that the user is not allowed to see.
  #
  # Regardless authorization should happen in every controller action (whenever
  # `current_user` is invoked) and is handled by CanCanCan.
  # Authorization will automatically trigger authentication as well!
  #
  # Note if an invalid authentication mechanism is supplied the request should
  # fail, even if the current resource is publicly accessible.
  #
  # Override this method in controllers to change the behaviour.
  # @return [Boolean]
  def should_authenticate_user?
    return false if action_sym == :new
    return false if action_sym == :index
    return false if action_sym == :filter
    return false if action_sym == :show
    return false if devise_controller?

    true
  end

  def should_check_authorization?
    return false if devise_controller?

    true
  end
end
