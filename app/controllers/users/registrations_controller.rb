class Users::RegistrationsController < Devise::RegistrationsController
  include Api::ApiAuth
  # NOTE: do not 'include Api::ControllerHelper' as it will mess with the devise controller methods

  # skip the default devise :authenticate_user! as it does not cater for api auth
  skip_before_action :authenticate_scope!, only: [:destroy]

  # custom authentication for api only
  before_action :authenticate_user_custom!

  # ensure the resource is set, as devise' usual authenticate_scope! callback has been replaced
  before_action do
    self.resource = current_user
  end

  # DELETE /resource
  def destroy
    # this is used only by a user archiving their own account

    if current_user && current_user.deleted?
      fail CustomErrors::DeleteNotPermittedError.new(I18n.t('baw.shared.actions.cannot_hard_delete_account'))
    end

    authorize! :destroy, :api_registrations

    # user destroying own account
    if Access::Core.is_standard_user?(current_user)
      # see devise-4.2.0/app/controllers/devise/registrations_controller.rb#destroy
      resource.destroy
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
      respond_to do |format|
        format.html {
          set_flash_message! :notice, :destroyed
          redirect_to after_sign_out_path_for(resource_name) }
        format.json {
          # do 'respond_destroy' manually
          built_response = Settings.api_response.build(:no_content, nil)
          render json: built_response, status: :no_content, layout: false
        }
      end
    else
      # other types of users cannot be destroyed
      fail CustomErrors::BadRequestError.new(t('baw.shared.actions.cannot_delete_account'))
    end
  end

end
