# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  # https://github.com/heartcombo/devise/blob/c9e655e13253dc53e3c0981a8345f134bcda1fc5/app/controllers/devise/confirmations_controller.rb#L22
  #
  # We want to redirect a user to `client_routes.home_url` after confirmation,
  # but rails protects against redirecting to external hosts by default.
  # To bypass, we copy the default devise confirmable show method, but add
  # `allow_other_host: true` to the redirect_to call.
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    yield resource if block_given?

    if resource.errors.empty?
      set_flash_message!(:notice, :confirmed)
      respond_with_navigational(resource) do
        redirect_to after_confirmation_path_for(resource_name, resource), allow_other_host: true
      end
    else
      respond_with_navigational(resource.errors, status: :unprocessable_entity) { render :new }
    end
  end

  protected

  def after_confirmation_path_for(_resource_name, _resource)
    Settings.client_routes.home_url.to_s
  end
end
