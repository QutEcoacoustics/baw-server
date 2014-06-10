class PermissionsController < ApplicationController
  add_breadcrumb 'Home', :root_path

  load_and_authorize_resource :project
  load_and_authorize_resource :permission, through: :project


  before_filter :add_project_breadcrumb

  # GET /permissions
  # GET /permissions.json
  def index
    @permissions = @project.permissions
    @project.permissions.new  # this is required for the form to render

    respond_to do |format|
      format.html {
        # Only deny access to html, because it basically renders an EDIT page
        # We need to raise AccessDenied because cancan doesn't allow project read AND permissions deny at the same time without having a permission object, which in this case we don't have
        if cannot? :update_permissions, @project
          raise CanCan::AccessDenied.new(I18n.t('devise.failure.unauthorized'), :index, Permission)
        end
        add_breadcrumb 'Permissions', project_permissions_path(@project)
      }# index.html.erb
      format.json { render json: @permissions }
    end
  end

  # GET /permissions/1
  # GET /permissions/1.json
  def show
    @permission = Permission.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @permission }
    end
  end

  # GET /permissions/new
  # GET /permissions/new.json
  def new
    @permission = Permission.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @permission.to_json(:only => [:user_id, :level]) }
    end
  end

  # GET /permissions/1/edit
  def edit
    @permission = Permission.find(params[:id])
  end

  # POST /permissions
  # POST /permissions.json
  def create
    @permission = Permission.new(params[:permission])
    @project.permissions << @permission
    @permission.creator = current_user

    respond_to do |format|
      if @permission.save
        format.json { render json: @permission, status: :created, location: @permission }
      else
        format.json { render json: @permission.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /permissions/1
  # PUT /permissions/1.json
  def update
    @permission = Permission.find(params[:id])
    @permission.updater = current_user

    respond_to do |format|
      if @permission.update_attributes(params[:permission])
        format.html { redirect_to project_permissions_url(@project), notice: 'Permission was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @permission.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /permissions/1
  # DELETE /permissions/1.json
  def destroy
    @permission = Permission.find(params[:id])
    @permission.destroy

    respond_to do |format|
      format.html { redirect_to project_permissions_url(@project) }
      format.json { head :no_content }
    end
  end

  private
  def add_project_breadcrumb
    add_breadcrumb 'Projects', projects_path
    add_breadcrumb @project.name, @project
  end

end
