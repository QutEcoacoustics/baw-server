class UserAccountsController < ApplicationController

  load_and_authorize_resource :class => 'User'

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
    @user = User.find(params[:id])
    @user_annotations = @user.recently_added_audio_events(params[:page])
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user }
    end
  end

  def my_account
    @user = current_user
    @user_annotations = @user.recently_added_audio_events(params[:page])
    respond_to do |format|
      format.html { render template: 'user_accounts/show' }
      format.json { render json: @user }
    end
  end

  # GET /users/new
  # GET /users/new.json
  def new
    @user = User.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @user }
    end
  end

  # GET /users/1/edit
  def edit
    @user = User.find(params[:id])
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(params[:user])

    respond_to do |format|
      if @user.save
        format.html { redirect_to user_account_path(@user), notice: 'User was successfully created.' }
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render action: 'new' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.json
  def update

    # https://github.com/plataformatec/devise/wiki/How-To%3a-Allow-users-to-edit-their-account-without-providing-a-password
    if params[:user][:password].blank?
      params[:user].delete('password')
      params[:user].delete('password_confirmation')
    end

    @user = User.find(params[:id])

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

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to user_accounts_url }
      format.json { head :no_content }
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
    @user = User.find(params[:id])
    @user_projects = @user.projects
    respond_to do |format|
      format.html # projects.html.erb
      format.json { render json: @user_projects }
    end
  end

end
