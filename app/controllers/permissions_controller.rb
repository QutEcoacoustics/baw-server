# frozen_string_literal: true

class PermissionsController < ApplicationController
  include Api::ControllerHelper

  # GET /projects/:project_id/permissions
  def index
    do_authorize_class
    get_project
    respond_to do |format|
      format.html do
        do_authorize_instance(:update_permissions, @project)

        result = update_permissions

        case result
        when true
          flash[:success] = 'Permissions successfully updated.'
        when false
          flash[:error] = 'There was an error updating permissions. Please try again or contact us.'
        end

        params[:page] ||= 'a-b'
        redirect_to project_permissions_path(@project, page: params[:page]) unless result.nil?
        @permissions = Permission.where(project: @project)
        @users = User.users.alphabetical_page(:user_name, params[:page])
      end
      format.json {
        @permissions, opts = Settings.api_response.response_advanced(
          api_filter_params,
          Access::ByPermission.permissions(Current.user, project_id: @project.id),
          Permission,
          Permission.filter_settings
        )
        respond_index(opts)
      }
    end
  end

  # GET /projects/:project_id/permissions/:id
  def show
    do_load_resource
    get_project
    do_authorize_instance

    respond_to do |format|
      format.json { respond_show }
    end
  end

  # GET /projects/:project_id/permissions/new
  def new
    do_new_resource
    get_project
    do_set_attributes
    do_authorize_instance

    respond_to do |format|
      format.json { respond_new }
    end
  end

  # POST /projects/:project_id/permissions
  def create
    do_new_resource
    do_set_attributes(permission_params)
    get_project
    do_authorize_instance

    respond_to do |format|
      if @permission.save
        format.json { respond_create_success(project_permission_path(@project, @permission)) }
      else
        format.json { respond_change_fail }
      end
    end
  end

  # PUT|PATCH /projects/:project_id/permissions/:id
  def update
    do_load_resource #      @permission = Permission.find(params[:id])
    get_project #           @project = Project.find(params[:project_id])
    do_authorize_instance # authorize! :update @permission

    if @permission.update(permission_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /projects/:project_id/permissions/:id
  def destroy
    do_load_resource
    get_project
    do_authorize_instance

    @permission.destroy

    respond_to do |format|
      format.json { respond_destroy }
    end
  end

  # GET|POST /projects/:project_id/permissions/filter
  def filter
    do_authorize_class
    get_project
    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.permissions(current_user, project_id: @project.id),
      Permission,
      Permission.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def get_project
    @project = Project.find(params[:project_id])

    return unless defined?(@permission)

    @permission.project = @project
    @permission.project_id = @project.id
  end

  def permission_params
    params.require(:permission).permit(:level, :project_id, :user_id, :allow_logged_in, :allow_anonymous)
  end

  def update_permissions_params
    params.slice(:project_wide, :per_user).permit(project_wide: [:logged_in, :anonymous],
      per_user: [:none, :reader, :writer, :owner])
  end

  def update_permissions
    return nil if !params.include?(:project_wide) && !params.include?(:per_user)

    request_params = update_permissions_params

    if request_params.include?(:project_wide) && request_params[:project_wide].include?(:logged_in)
      permission = Permission.where(project: @project, user: nil, allow_logged_in: true, allow_anonymous: false).first
      if permission.blank?
        permission = Permission.new(project: @project, user: nil, allow_logged_in: true, allow_anonymous: false)
      end
      new_level = request_params[:project_wide][:logged_in].to_s
    elsif request_params.include?(:project_wide) && request_params[:project_wide].include?(:anonymous)
      permission = Permission.where(project: @project, user: nil, allow_logged_in: false, allow_anonymous: true).first
      if permission.blank?
        permission = Permission.new(project: @project, user: nil, allow_logged_in: false, allow_anonymous: true)
      end
      new_level = request_params[:project_wide][:anonymous].to_s
    elsif request_params.include?(:per_user)
      user_id = request_params[:per_user].values.first.to_i
      permission = Permission.where(project: @project, user_id:, allow_logged_in: false,
        allow_anonymous: false).first
      if permission.blank?
        permission = Permission.new(project: @project, user_id:, allow_logged_in: false, allow_anonymous: false)
      end
      new_level = request_params[:per_user].keys.first.to_s
    else
      permission = nil
      new_level = nil
    end

    if new_level.to_s.downcase == 'none'
      result = permission.destroy
      result = !result.nil? && result.is_a?(Permission)
    else
      permission.level = new_level
      result = permission.save
    end

    result
  end
end
