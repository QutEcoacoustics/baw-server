class Users::RegistrationsController < Devise::RegistrationsController

  # DELETE /resource
  def destroy
    # this is used only by a user archiving their own account

    if current_user.deleted?
      fail CustomErrors::DeleteNotPermittedError.new(I18n.t('baw.shared.actions.cannot_hard_delete_account'))
    end

    authorize! :destroy, :api_registrations

    # user destroying own account
    if Access::Core.is_standard_user?(current_user)
      super
    else
      # other types of users cannot be destroyed
      fail CustomErrors::BadRequestError.new(t('baw.shared.actions.cannot_delete_account'))
    end
  end

end
