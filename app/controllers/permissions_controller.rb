class PermissionsController < ApplicationController
  include Api::ControllerHelper

  # GET /projects/:project_id/permissions
  def index
    do_authorize_class
    get_project
    do_authorize_instance(:update_permissions, @project)

    respond_to do |format|
      format.html {
        @permissions = Permission.project_list(@project.id)
      }
      format.json {
        @permissions, opts = Settings.api_response.response_advanced(
            api_filter_params,
            Access::Model.permissions(current_user, Access::Core.levels_allow, @project),
            Permission,
            Permission.filter_settings)
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
      format.json { respond_show }
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

  private

  def get_project
    @project = Project.find(params[:project_id])

    # avoid the same project assigned more than once to a site
    if defined?(@permission) && @permission.project.blank?
      @permission.project = @project
    end
  end

  def permission_params
    params.require(:permission).permit(:level, :project_id, :user_id)
  end

end
