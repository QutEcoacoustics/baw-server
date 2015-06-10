class PermissionsController < ApplicationController
  include Api::ControllerHelper

  add_breadcrumb 'Home', :root_path

  # order matters for before_action and load_and_authorize_resource!
  load_and_authorize_resource :project

  # this is necessary so that the ability has access to permission.project
  before_action :build_project_permission, only: [:new, :create]

  load_and_authorize_resource :permission, through: :project

  before_action :add_project_breadcrumb, only: [:index]

  respond_to :json

  # GET /permissions
  # GET /permissions.json
  def index
    #@permissions = @project.permissions
    #@project.permissions.new # this is required for the form to render

    # Only deny access to html, because it basically renders an EDIT page
    # We need to raise AccessDenied because cancan doesn't allow project read AND permissions deny at the same
    # time without having a permission object, which in this case we don't have
    if cannot? :update_permissions, @project
      fail CanCan::AccessDenied.new(I18n.t('devise.failure.unauthorized'), :index, Permission)
    end

    respond_to do |format|
      format.html {

        add_breadcrumb 'Permissions', project_permissions_path(@project)
      } # index.html.erb
      format.json {
        @permissions, opts = Settings.api_response.response_advanced(
            api_filter_params,
            Permission.where(project_id: @project.id),
            Permission,
            Permission.filter_settings
        )
        respond_index(opts)
      }
    end
  end

  # GET /permissions/1.json
  def show
    respond_show
  end

  # GET /permissions/new.json
  def new
    do_authorize!

    respond_show
  end

  # POST /permissions.json
  def create
    attributes_and_authorize(permission_params)

    if @permission.save
      respond_create_success(project_permission_url(@project, @permission))
    else
      respond_change_fail
    end

  end

  # DELETE /permissions/1.json
  def destroy
    @permission.destroy
    respond_destroy
  end

  def filter
    authorize! :filter, Permission
    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Permission.where(project_id: @project.id),
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private
  def add_project_breadcrumb
    add_breadcrumb 'Projects', projects_path
    add_breadcrumb @project.name, @project
  end

  def build_project_permission
    @permission = Permission.new
    @permission.project = @project
  end

  def permission_params
    params.require(:permission).permit(:level, :project_id, :user_id)
  end

end
