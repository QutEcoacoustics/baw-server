# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  # https://github.com/heartcombo/devise/blob/v5.0.3/app/controllers/devise/passwords_controller.rb
  #
  # We want to redirect to `client_routes.home_url` after a password reset, but
  # Rails protects against redirecting to external hosts by default. To bypass,
  # copy Devise's update action and allow the external redirect.
  def update
    self.resource = resource_class.reset_password_by_token(resource_params)
    yield resource if block_given?

    if resource.errors.empty?
      resource.unlock_access! if unlockable?(resource)
      if sign_in_after_reset_password?
        flash_message = resource.active_for_authentication? ? :updated : :updated_not_active
        set_flash_message!(:notice, flash_message)
        resource.after_database_authentication
        sign_in(resource_name, resource)
      else
        set_flash_message!(:notice, :updated_not_active)
      end
      respond_with_navigational(resource) do
        redirect_to after_resetting_password_path_for(resource), allow_other_host: true
      end
    else
      set_minimum_password_length
      respond_with resource
    end
  end

  protected

  def after_resetting_password_path_for(_resource)
    Settings.client_routes.home_url.to_s
  end
end
