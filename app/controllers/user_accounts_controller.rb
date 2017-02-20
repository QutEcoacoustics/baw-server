class UserAccountsController < ApplicationController
  include Api::ControllerHelper

  # these actions are used by both standard users and admins

  # GET /user_accounts
  def index
    # only admin has access to index

    do_authorize_class

    order = 'CASE WHEN last_seen_at IS NOT NULL THEN last_seen_at
WHEN current_sign_in_at IS NOT NULL THEN current_sign_in_at
ELSE last_sign_in_at END DESC'
    # included archied users
    @users = User.with_deleted.order(order).page(params[:page])

    respond_to do |format|
      format.html
    end
  end

  # GET /user_accounts/:id
  def show
    # admin, this account's user, and other users can access show
    if Access::Core.is_admin?(current_user)
      do_load_with_deleted_resource
    else
      # users who are not admin cannot access archived user's details
      do_load_resource
    end

    do_authorize_instance

    respond_to do |format|
      format.html # show.html.erb
      format.json { respond_show }
    end
  end

  # GET /my_account
  def my_account
    # admin and this account's user can access my_account
    @user = current_user

    do_authorize_instance

    respond_to do |format|
      format.html { render template: 'user_accounts/show' }
      format.json { respond_show }
    end
  end

  # GET /user_accounts/:id/edit
  def edit
    # only admins have access to edit
    do_load_with_deleted_resource
    do_authorize_instance
  end

  # PUT|PATCH /user_accounts/:id
  def update
    # only admins have access to update
    do_load_with_deleted_resource
    do_authorize_instance

    the_params = user_update_params.dup

    # https://github.com/plataformatec/devise/wiki/How-To%3a-Allow-users-to-edit-their-account-without-providing-a-password
    if the_params[:password].blank?
      the_params.delete('password')
      the_params.delete('password_confirmation')
    end

    # don't send confirmation email - change email straight away.
    @user.skip_reconfirmation!

    # confirm or un-confirm if relevant button was clicked
    if params[:commit] == 'Remove Confirmation'
      @user.confirmed_at = nil
      @user.save!
    end

    if params[:commit] == 'Confirm User'
      @user.confirm
    end

    if params[:commit] == 'Resend Confirmation'
      @user.resend_confirmation_instructions
    end

    respond_to do |format|
      if @user.update_attributes(the_params)
        format.html { redirect_to user_account_path(@user), notice: 'User was successfully updated.' }
        format.json { respond_show }
      else
        format.html { render action: 'edit' }
        format.json { respond_change_fail }
      end
    end
  end

  # DELETE /user_accounts/:id
  def destroy
    # admin only has access to destroy
    # users delete their own account using DELETE /my_account ( users/registrations#destroy )

    # do_load_resource will fail for an archived user
    # this is what we want - cannot hard delete a user from UI, even if admin
    do_load_resource
    do_authorize_instance

    if @user.deleted?
      # just make sure that we cannot hard delete a user from UI, even if admin!
      fail CustomErrors::DeleteNotPermittedError.new(I18n.t('baw.shared.actions.cannot_hard_delete_account'))
    end

    if Access::Core.is_standard_user?(@user)
      user_was_active = do_check_resource_exists?
      @user.destroy

      # archived at header is only added if user is not archived already
      add_archived_at_header(@user) if user_was_active

      respond_to do |format|
        format.html { redirect_to user_accounts_path, notice: I18n.t('baw.shared.actions.user_deleted') }
        format.json { respond_destroy }
      end
    else
      fail CustomErrors::BadRequestError.new(t('baw.shared.actions.cannot_delete_account'))
    end
  end

  # PUT /my_account/prefs
  def modify_preferences
    @user = current_user
    do_authorize_instance

    # sometimes faulty timezones are stored, repair them
    TimeZoneHelper.parse_model(@user)

    @user.preferences = user_account_params

    respond_to do |format|
      if @user.save
        format.json { respond_show }
      else
        format.json { respond_change_fail }
      end
    end
  end

  # GET /user_accounts/:id/projects
  def projects
    do_load_resource
    do_authorize_instance

    @user_projects = Access::ByPermission.projects(@user).includes(:creator).references(:creator)
                         .order('projects.name ASC')
                         .page(paging_params[:page].blank? ? 1 : paging_params[:page])
    respond_to do |format|
      format.html
    end
  end

  # GET /user_accounts/:id/sites
  def sites
    do_load_resource
    do_authorize_instance

    @user_sites = Access::ByPermission.sites(@user).includes(:creator, :projects).references(:creator, :project)
                      .order('sites.name ASC')
                      .page(paging_params[:page].blank? ? 1 : paging_params[:page])

    respond_to do |format|
      format.html
    end
  end

  # GET /user_accounts/:id/bookmarks
  def bookmarks
    do_load_resource
    do_authorize_instance

    @user_bookmarks = Access::ByUserModified.bookmarks(@user)
                          .order('bookmarks.updated_at DESC')
                          .page(paging_params[:page].blank? ? 1 : paging_params[:page])
    respond_to do |format|
      format.html
    end
  end

  # GET /user_accounts/:id/audio_event_comments
  def audio_event_comments
    do_load_resource
    do_authorize_instance

    @user_audio_event_comments = Access::ByUserModified.audio_event_comments(@user)
                                     .order('audio_event_comments.updated_at DESC')
                                     .page(paging_params[:page].blank? ? 1 : paging_params[:page])
    respond_to do |format|
      format.html
    end
  end

  # GET /user_accounts/:id/audio_events
  def audio_events
    do_load_resource
    do_authorize_instance

    @user_annotations = Access::ByUserModified.audio_events(@user).includes(audio_recording: [:site]).references(:audio_recordings, :sites)
                            .order('audio_events.updated_at DESC')
                            .page(paging_params[:page].blank? ? 1 : paging_params[:page])
    respond_to do |format|
      format.html
    end
  end

  # GET /user_accounts/:id/saved_searches
  def saved_searches
    do_load_resource
    do_authorize_instance

    @user_saved_searches = Access::ByUserModified.saved_searches(@user)
                               .order('saved_searches.created_at DESC')
                               .paginate(
                                   page: paging_params[:page].blank? ? 1 : paging_params[:page],
                                   per_page: 30
                               )
    respond_to do |format|
      format.html
    end
  end

  # GET /user_accounts/:id/analysis_jobs
  def analysis_jobs
    do_load_resource
    do_authorize_instance

    @user_analysis_jobs = Access::ByUserModified.analysis_jobs(@user)
                              .order('analysis_jobs.updated_at DESC')
                              .paginate(
                                  page: paging_params[:page].blank? ? 1 : paging_params[:page],
                                  per_page: 30
                              )
    respond_to do |format|
      format.html
    end
  end

  # GET|POST /user_accounts/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        User.all,
        User,
        User.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  # override resource name
  def resource_name
    'user'
  end

  def user_params
    params.require(:user).permit(
        :user_name, :email, :password, :password_confirmation, :remember_me,
        :roles, :roles_mask, :preferences,
        :image, :login)
  end

  def user_update_params
    params.require(:user).permit(
        :id, :user_name, :email, :tzinfo_tz,
        :password, :password_confirmation,
        :roles_mask, :image)
  end

  def paging_params
    params.permit(:page, :id)
  end

  def user_account_params
    params.require(:user_account).permit!
  end

end
