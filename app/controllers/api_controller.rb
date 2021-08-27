# frozen_string_literal: true

# Base controller for our API endpoints
#class ApiController < ActionController::API
# Had to walk back this change:
# - Cookies middleware are not added to the API controller by default
#   https://github.com/rails/rails/issues/24239
# - We are still relying on cookies for CSRF protection and other things
# - Trying to access cookies without fixing either of the above issues
#   results in a stack overflow in some rails based test helper for requests:
#   action_dispatch/testing/test_process.rb:68:in `cookies'
class ApiController < ActionController::Base
  # TODO: remove this when we clean up our cookies/auth problems
  include ActionController::RequestForgeryProtection
  include include ActiveStorage::SetCurrent

  include IncludeController

  layout 'api'
end
