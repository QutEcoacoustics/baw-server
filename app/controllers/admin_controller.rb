# frozen_string_literal: true

# Base controller for admin only endpoints
class AdminController < ApplicationController
  # unlike other controllers, no public endpoints should be exposed from
  # any admin controller.
  def should_authenticate_user?
    true
  end

  def should_check_authorization?
    true
  end
end
