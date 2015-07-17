class UserAccountsController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource :user, parent: false

  # GET /users
  # GET /users.json
  def index
    order = 'CASE WHEN last_seen_at IS NOT NULL THEN last_seen_at
WHEN current_sign_in_at IS NOT NULL THEN current_sign_in_at
ELSE last_sign_in_at END DESC'
    @users = User.order(order).all

    respond_to do |format|
      format.html
      # no json API to list users
    end
  end

  # GET /users/1
  # GET /users/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { respond_show }
    end
  end

  def my_account
    @user = current_user
    respond_to do |format|
      format.html { render template: 'user_accounts/show' }
      format.json { respond_show }
    end
  end

  # GET /users/1/edit
  def edit

  end

  # PUT /users/1
  # PUT /users/1.json
  def update

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

  # PUT /my_account/prefs.json
  def modify_preferences

    @user = current_user
    @user.preferences = user_account_params

    respond_to do |format|
      if @user.save
        format.json { respond_show }
      else
        format.json { respond_change_fail }
      end
    end
  end

  # GET /user_accounts/1/projects
  def projects
    @user_projects = Access::Query.projects_accessible(@user).includes(:creator).references(:creator)
                         .order('projects.updated_at DESC')
                         .paginate(
                             page: paging_params[:page].blank? ? 1 : paging_params[:page],
                             per_page: 30
                         )
    respond_to do |format|
      format.html # projects.html.erb
      format.json { render json: @user_projects }
    end
  end

  # GET /user_accounts/1/bookmarks
  def bookmarks
    @user_bookmarks = Access::Query.bookmarks_modified(@user)
                          .order('bookmarks.updated_at DESC')
                          .paginate(
                              page: paging_params[:page].blank? ? 1 : paging_params[:page],
                              per_page: 30
                          )
    respond_to do |format|
      format.html # bookmarks.html.erb
      format.json { render json: @user_bookmarks }
    end
  end

  # GET /user_accounts/1/audio_event_comments
  def audio_event_comments
    @user_audio_event_comments = Access::Query.audio_event_comments_modified(@user)
                                     .order('audio_event_comments.updated_at DESC')
                                     .paginate(
                                         page: paging_params[:page].blank? ? 1 : paging_params[:page],
                                         per_page: 30
                                     )
    respond_to do |format|
      format.html # audio_event_comments.html.erb
      format.json { render json: @user_audio_event_comments }
    end
  end

  def audio_events
    @user_annotations = Access::Query.audio_events_modified(@user).includes(:audio_recording).references(:audio_recordings)
                            .order('audio_events.updated_at DESC')
                            .paginate(
                                page: paging_params[:page].blank? ? 1 : paging_params[:page],
                                per_page: 30
                            )
    respond_to do |format|
      format.html # audio_events.html.erb
      format.json { render json: @user_annotations }
    end
  end

  def filter
    authorize! :filter, User
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
        :id, :user_name, :email,
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
