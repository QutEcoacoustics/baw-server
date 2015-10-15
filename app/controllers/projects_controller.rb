class ProjectsController < ApplicationController
  include Api::ControllerHelper

  # GET /projects
  def index
    do_authorize_class

    respond_to do |format|
      format.html {
        @projects = Access::Model.projects(current_user).includes(:creator).references(:creator)
      }
      format.json {
        @projects, opts = Settings.api_response.response_advanced(
            api_filter_params,
            Access::Model.projects(current_user),
            Project,
            Project.filter_settings
        )
        respond_index(opts)
      }
    end
  end

  # GET /projects/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_to do |format|
      format.html
      format.json { respond_show }
    end
  end

  # GET /projects/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_to do |format|
      format.html
      format.json { respond_show }
    end
  end

  # GET /projects/:id/edit
  def edit
    do_load_resource
    do_authorize_instance
  end

  # GET /projects/:id/edit_sites
  def edit_sites
    do_load_resource
    do_authorize_instance

    @site_info = Site.connection.select_all("SELECT s.id, s.name,
(SELECT count(*) FROM projects_sites ps WHERE s.id = ps.site_id) AS project_count,
 (SELECT count(*) FROM audio_recordings ar WHERE s.id = ar.site_id) AS audio_recording_count
FROM sites s
ORDER BY project_count ASC, s.name ASC")
  end

  # POST /projects
  def create
    do_new_resource
    do_set_attributes(project_params)
    do_authorize_instance

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { respond_create_success }
      else
        format.html { render action: 'new' }
        format.json { respond_change_fail }
      end
    end
  end

  # PUT|PATCH /projects/:id
  def update
    do_load_resource
    do_authorize_instance

    respond_to do |format|
      if @project.update_attributes(project_params)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { respond_show }
      else
        format.html {
          render action: 'edit'
        }
        format.json { respond_change_fail }
      end
    end
  end

  # PUT|PATCH /project/:id/update_sites
  def update_sites
    do_load_resource
    do_authorize_instance

    old_site_ids = @project.sites.pluck(:id).map(&:to_i)
    new_site_ids = edit_sites_params[:site_ids].keys.map(&:to_i)

    changed = old_site_ids != new_site_ids

    if changed
      # to update project / site asociations:
      # first, delete all associations for this project
      # then add all specified associations

      @project.site_ids = new_site_ids
      @project.save!

      redirect_to edit_sites_project_path(@project), notice: 'Sites for this project were updated.'
    else
      redirect_to edit_sites_project_path(@project), notice: 'Sites for this project were unchanged.'
    end

  end

  # PUT|PATCH /projects/:id/update_permissions
  def update_permissions
    do_load_resource
    do_authorize_instance

    request_params = update_permissions_params

    if request_params.include?(:project_wide) && request_params[:project_wide].include?(:logged_in)
      permission = Permission.where(project: @project, user: nil, allow_logged_in: true, allow_anonymous: false).first
      permission = Permission.new(project: @project, user: nil, allow_logged_in: true, allow_anonymous: false) if permission.blank?
      level = request_params[:project_wide][:logged_in].to_s
    elsif request_params.include?(:project_wide) && request_params[:project_wide].include?(:anonymous)
      permission = Permission.where(project: @project, user: nil, allow_logged_in: false, allow_anonymous: true).first
      permission = Permission.new(project: @project, user: nil, allow_logged_in: false, allow_anonymous: true) if permission.blank?
      level = request_params[:project_wide][:anonymous].to_s
    elsif request_params.include?(:per_user)
      user_id = request_params[:per_user].values.first.to_i
      permission = Permission.where(project: @project, user_id: user_id, allow_logged_in: false, allow_anonymous: false).first
      permission = Permission.new(project: @project, user_id: user_id, allow_logged_in: false, allow_anonymous: false) if permission.blank?
      level = request_params[:per_user].keys.first.to_s
    else
      permission = nil
      level = nil
    end

    result = process_permission_update(permission, level)

    respond_to do |format|
      if result
        format.html { redirect_to project_permissions_path(@project), notice: 'Permissions were successfully updated.' }
        #format.json { render json: permission_to_modify, status: :created, location: permission_to_modify }
      else
        format.html { redirect_to project_permissions_path(@project), alert: 'Permissions were not updated.' }
        #format.json { render json: permission_to_modify.errors, status: :unprocessable_entity }
      end
    end

  end

  # DELETE /projects/:id
  def destroy
    do_load_resource
    do_authorize_instance

    @project.destroy
    add_archived_at_header(@project)

    respond_to do |format|
      format.html { redirect_to projects_url }
      format.json { respond_destroy }
    end
  end

  # GET /projects/new_access_request
  def new_access_request
    do_authorize_class

    @all_projects = Access::Model.projects(current_user, nil).order(name: :asc)
    respond_to do |format|
      format.html
    end
  end

  # POST /projects/submit_access_request
  def submit_access_request
    do_authorize_class

    valid_request = access_request_params.include?(:projects) &&
        access_request_params[:projects].is_a?(Array) &&
        access_request_params[:projects].size > 1 &&
        access_request_params.include?(:reason) &&
        access_request_params[:reason].is_a?(String) &&
        access_request_params[:reason].size > 0

    respond_to do |format|
      if valid_request
        ProjectMailer.project_access_request(current_user, access_request_params[:projects], access_request_params[:reason]).deliver_now
        format.html { redirect_to projects_path, notice: 'Access request successfully submitted.' }
      else
        format.html {
          redirect_to new_access_request_projects_path, alert: 'Please select projects and provide reason for access.'
        }
      end
    end
  end

  # GET|POST /projects/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::Model.projects(current_user),
        Project,
        Project.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def project_params
    params.require(:project).permit(:description, :image, :name, :notes, :urn)
  end

  def access_request_params
    params.require(:access_request).permit({projects: []}, :reason)
  end

  def update_permissions_params
    params.permit(project_wide: [:logged_in, :anonymous], per_user: [:none, :reader, :writer, :owner])
  end

  def edit_sites_params
    params.require(:project).permit!
  end

  def process_permission_update(permission, new_level)
    if new_level.to_s.downcase == 'none'
      permission.destroy
    else
      permission.level = new_level
      permission.save
    end
  end

end
