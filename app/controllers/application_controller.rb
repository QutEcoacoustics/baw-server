# frozen_string_literal: true

# Base controller for our application (including legacy support for views/non-API responses)
class ApplicationController < ActionController::Base
  include IncludeController

  include ActiveStorage::SetCurrent
  include SetCurrent

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
end
