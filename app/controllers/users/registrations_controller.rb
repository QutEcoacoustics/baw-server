class Users::RegistrationsController < Devise::RegistrationsController
  include Api::ApiAuth

  # remove devise authenticate prepend_before_action as it does not take account of the custom user authentication
  skip_before_action :authenticate_scope!, only: [:destroy]

  # register the custom user authentication (from body or header)
  prepend_before_action :authenticate_user_custom!, only: [:destroy]

  # DELETE /resource
  def destroy
    authorize! :destroy, :user

    if Access::Core.is_standard_user?(resource)
      super
    else
      fail CustomErrors::BadRequestError.new(t('baw.shared.actions.cannot_delete_account'))
    end
  end

end
