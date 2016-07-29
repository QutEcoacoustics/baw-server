class UserAccountsController < ApplicationController
  include Api::ControllerHelper

  # GET /user_accounts
  def index
    do_authorize_class

    order = 'CASE WHEN last_seen_at IS NOT NULL THEN last_seen_at
WHEN current_sign_in_at IS NOT NULL THEN current_sign_in_at
ELSE last_sign_in_at END DESC'
    @users = User.order(order).page(params[:page])

    respond_to do |format|
      format.html
      # no json API to list users
    end
  end

  # GET /user_accounts/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_to do |format|
      format.html # show.html.erb
      format.json { respond_show }
    end
  end

  # GET /my_account
  def my_account
    @user = current_user

    do_authorize_instance

    respond_to do |format|
      format.html { render template: 'user_accounts/show' }
      format.json { respond_show }
    end
  end

  # GET /user_accounts/:id/edit
  def edit
    do_load_resource
    do_authorize_instance
  end

  # PUT|PATCH /user_accounts/:id
  def update
    do_load_resource
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
      @user.confirm!
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

  # PUT /my_account/prefs
  def modify_preferences
    @user = current_user
    do_authorize_instance

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

    @user_projects = Access::Query.projects_accessible(@user).includes(:creator).references(:creator)
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

    @user_sites = Access::Query.sites(@user).includes(:creator, :projects).references(:creator, :project)
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

    @user_bookmarks = Access::Query.bookmarks_modified(@user)
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

    @user_audio_event_comments = Access::Query.audio_event_comments_modified(@user)
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

    @user_annotations = Access::Query.audio_events_modified(@user).includes(audio_recording: [:site]).references(:audio_recordings, :sites)
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

    @user_saved_searches = Access::Query.saved_searches_modified(@user)
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

    @user_analysis_jobs = Access::Query.analysis_jobs_modified(@user)
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
