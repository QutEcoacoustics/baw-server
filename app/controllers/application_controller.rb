# frozen_string_literal: true

# Base controller for our application (including legacy support for views/non-API responses)
class ApplicationController < ActionController::Base
  include IncludeController

  layout :select_layout

  def select_layout
    if json_request?
      'api'
    else
      'application'
    end
  end
end
