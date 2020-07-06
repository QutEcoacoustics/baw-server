# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :verify_admin

    # Return true if it's an admin controller. false to all controllers unless
    # the controller is defined inside Admin namespace. Useful if you want to apply a before
    # filter to all controllers, except the ones in the admin namespace:
    #
    #   before_action :my_filter, unless: :admin_controller?
    def admin_controller?
      is_a?(Admin::BaseController)
    end

    private

    def verify_admin
      raise CanCan::AccessDenied, 'Administrator access only.' unless Access::Core.is_admin?(current_user)
    end
  end
end
