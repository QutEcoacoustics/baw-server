class ProjectsController < ApplicationController
  include Api::ControllerHelper

  add_breadcrumb 'Home', :root_path

  load_and_authorize_resource :project

  # GET /projects
  # GET /projects.json
  def index
    respond_to do |format|
      format.html {
        @projects = get_user_projects
        add_breadcrumb 'Projects', projects_path
      }
      format.json {
        @projects, constructed_options = Settings.api_response.response_index(
            params,
            get_user_projects,
            Project,
            Project.filter_settings
        )
        respond_index
      }
    end
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    respond_to do |format|
      format.html {
        add_breadcrumb 'Projects', projects_path
        add_breadcrumb @project.name, @project

        @markers = @project.sites.to_gmaps4rails do |site, marker|
          marker.infowindow site.name
          marker.title site.name
        end

      }
      format.json { respond_show }
    end
  end

  # GET /projects/new
  # GET /projects/new.json
  def new
    respond_to do |format|
      format.html {
        add_breadcrumb 'Projects', projects_path
        add_breadcrumb 'New Project'
      }
      format.json { respond_show }
    end
  end

  # GET /projects/1/edit
  def edit
    add_breadcrumb 'Projects', projects_path
    add_breadcrumb @project.name, @project
    add_breadcrumb 'Edit'
  end

  # POST /projects
  # POST /projects.json
  def create
    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { respond_create_success }
      else
        format.html {
          add_breadcrumb 'Projects', projects_path
          add_breadcrumb @project.name, @project
          render action: 'new'
        }
        format.json { respond_change_fail }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.json
  def update
    respond_to do |format|
      if @project.update_attributes(params[:project])
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { respond_show }
      else
        format.html {
          add_breadcrumb 'Projects', projects_path
          add_breadcrumb @project.name, @project
          render action: 'edit'
        }
        format.json { respond_change_fail }
      end
    end
  end

  # POST /update_permissions
  def update_permissions
    # 'user_ids'=>{'1'=>{'permissions'=>{'level'=>'read'}},'3'=>{'permissions'=>{'level'=>'write'}}}    params[:project][:users].each do |users_params|
    no_error = true

    # loop through all users to see if their permission has been updated or revoked
    User.all.each do |user|
      # if the user's permission has been set, create permission
      if params[:user_ids].has_key?(user.id.to_s)
        @permission = Permission.where(project_id: @project.id, user_id: user.id).first
        if @permission.blank?
          @permission = Permission.new
          @permission.project = @project
          @permission.user = user
          @permission.creator = current_user
        else
          @permission.updater = current_user
        end
        if params[:user_ids][user.id.to_s][:permissions][:level].blank?
          @permission.destroy
        else
          @permission.level = params[:user_ids][user.id.to_s][:permissions][:level]

          unless @permission.save
            no_error = false
          end
        end
      else # if the user's permission has NOT been set, destroy permission
        @permission = Permission.where(project_id: @project.id, user_id: user.id).first
        @permission.destroy unless @permission.blank?
      end
    end

    respond_to do |format|
      if no_error
        format.html { redirect_to project_permissions_path(@project), notice: 'Permissions were successfully updated.' }
        #format.json { render json: @permission, status: :created, location: @permission }
      else
        format.html { redirect_to project_permissions_path(@project), alert: 'Permissions were not updated.' }
        #format.json { render json: @permission.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project.destroy

    respond_to do |format|
      format.html { redirect_to projects_url }
      format.json { respond_destroy }
    end
  end

  # GET /projects/request_access
  def new_access_request
    @all_projects = current_user.inaccessible_projects
    respond_to do |format|
      format.html {
        add_breadcrumb 'Projects', projects_path
        add_breadcrumb 'Request Project Access', new_access_request_projects_path

      }
    end
  end

  # POST /projects/request_access
  def submit_access_request
    valid_request = params[:access_request].include?(:projects) &&
        params[:access_request][:projects].is_a?(Array) &&
        params[:access_request][:projects].size > 1 &&
        params[:access_request].include?(:reason) &&
        params[:access_request][:reason].is_a?(String) &&
        params[:access_request][:reason].size > 0

    respond_to do |format|
      if valid_request
        ProjectMailer.project_access_request(current_user, params[:access_request][:projects], params[:access_request][:reason]).deliver_now
        format.html { redirect_to projects_path, notice: 'Access request successfully submitted.' }
      else
        format.html {
          add_breadcrumb 'Projects', projects_path
          add_breadcrumb 'Request Project Access', new_access_request_projects_path
          redirect_to new_access_request_projects_path, alert: 'Please select projects and provide reason for access.'
        }
      end
    end
  end

  # POST /sites/filter.json
  # GET /sites/filter.json
  def filter
    filter_response = Settings.api_response.response_filter(
        params,
        get_user_projects,
        Project,
        Project.filter_settings
    )

    render_api_response(filter_response)
  end

  private

  def get_user_projects
    if current_user.has_role? :admin
      projects = Project.includes(:creator).order('lower(name) ASC')
    else
      projects = current_user.projects.sort { |a, b| a.name <=> b.name }
    end

    projects
  end

end
