# frozen_string_literal: true

# Base controller for our API endpoints
class ApiController < ActionController::API
  # TODO: remove this when we clean up our cookies/auth problems
  include ActionController::RequestForgeryProtection

  include IncludeController
end
