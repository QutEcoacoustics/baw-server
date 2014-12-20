class UserAccountsController < ApplicationController

  load_and_authorize_resource :user, parent: false

  # GET /users
  # GET /users.json
  def index
    order = 'CASE WHEN current_sign_in_at IS NULL THEN last_sign_in_at ELSE current_sign_in_at END DESC'
    @users = User.order(order).all

    respond_to do |format|
      format.html # no json API to list users
    end
  end

  # GET /users/1
  # GET /users/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user }
    end
  end

  def my_account
    @user = current_user
    respond_to do |format|
      format.html { render template: 'user_accounts/show' }
      format.json { render json: @user }
    end
  end

  # GET /users/1/edit
  def edit

  end

  # PUT /users/1
  # PUT /users/1.json
  def update

    # https://github.com/plataformatec/devise/wiki/How-To%3a-Allow-users-to-edit-their-account-without-providing-a-password
    if params[:user][:password].blank?
      params[:user].delete('password')
      params[:user].delete('password_confirmation')
    end

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to user_account_path(@user), notice: 'User was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /my_account/prefs.json
  def modify_preferences

    @user = current_user
    prefs_specified = false

    if !params.blank? && !params[:user_account].blank?
      @user.preferences = params[:user_account]
      prefs_specified = true
    end

    respond_to do |format|
      if prefs_specified
        if @user.save
          format.json { head :no_content }
        else
          format.json { render json: @user.errors, status: :unprocessable_entity }
        end
      else
        format.json { render json: {error: 'must include user preferences in body as json'}, status: :unprocessable_entity }
      end
    end
  end

  # GET /user_accounts/1/projects
  def projects
    @user_projects = AccessLevel.projects_accessible(@user)
    .reorder('projects.updated_at DESC')
    .paginate(
        page: params[:page].blank? ? 1 : params[:page],
        per_page: 30
    )
    respond_to do |format|
      format.html # projects.html.erb
      format.json { render json: @user_projects }
    end
  end

  # GET /user_accounts/1/bookmarks
  def bookmarks
    @user_bookmarks = @user.accessible_bookmarks.uniq
    .order('bookmarks.updated_at DESC')
    .paginate(
        page: params[:page].blank? ? 1 : params[:page],
        per_page: 30
    )
    respond_to do |format|
      format.html # bookmarks.html.erb
      format.json { render json: @user_bookmarks }
    end
  end

  # GET /user_accounts/1/audio_event_comments
  def audio_event_comments
    @user_audio_event_comments = @user.created_audio_event_comments.includes(:audio_event).uniq
    .order('audio_event_comments.updated_at DESC')
    .paginate(
        page: params[:page].blank? ? 1 : params[:page],
        per_page: 30
    )
    respond_to do |format|
      format.html # audio_event_comments.html.erb
      format.json { render json: @user_audio_event_comments }
    end
  end

  def audio_events
    @user_annotations = @user.accessible_audio_events.uniq
    .order('audio_events.updated_at DESC')
    .paginate(
        page: params[:page].blank? ? 1 : params[:page],
        per_page: 30
    )
    respond_to do |format|
      format.html # audio_events.html.erb
      format.json { render json: @user_annotations }
    end
  end

end
