class ProjectsController < ApplicationController
  add_breadcrumb 'Home', :root_path

  load_and_authorize_resource

  # GET /projects
  # GET /projects.json
  def index
    if current_user.has_role? :admin
      @projects = Project.includes(:owner)
    else
      @projects = current_user.projects
    end

    respond_to do |format|
      format.html {
        add_breadcrumb 'Projects', projects_path
      }
      format.json { render json: @projects }
    end
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    respond_to do |format|
      format.html {
        add_breadcrumb 'Projects', projects_path
        add_breadcrumb @project.name, @project
      }
      format.json { render json: @project }
    end
  end

  # GET /projects/new
  # GET /projects/new.json
  def new
    respond_to do |format|
      format.html {
        add_breadcrumb 'Projects', projects_path
        add_breadcrumb @project.name, @project
      }
      format.json { render json: @project }
    end
  end

  # GET /projects/1/edit
  def edit
    @project = Project.find(params[:id])
    add_breadcrumb 'Projects', projects_path
    add_breadcrumb @project.name, @project
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(params[:project])

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html {
          add_breadcrumb 'Projects', projects_path
          add_breadcrumb @project.name, @project
          render action: 'new'
        }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.json
  def update
    respond_to do |format|
      if @project.update_attributes(params[:project])
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { head :no_content }
      else
        format.html {
          add_breadcrumb 'Projects', projects_path
          add_breadcrumb @project.name, @project
          render action: 'edit'
        }
        format.json { render json: @project.errors, status: :unprocessable_entity }
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
        @permission = Permission.find_by_project_id_and_user_id(@project, user)
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
        @permission = Permission.find_by_project_id_and_user_id(@project, user)
        @permission.destroy unless @permission.blank?
      end
    end

    respond_to do |format|
      if no_error
        format.html { redirect_to project_permissions_path(@project), notice: 'Permissions were successfully updated.' }
        #format.json { render json: @permission, status: :created, location: @permission }
      else
        format.html { redirect_to project_permissions_path(@project), alert: 'Permissions were not updated.'  }
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
      format.json { head :no_content }
    end
  end
end
