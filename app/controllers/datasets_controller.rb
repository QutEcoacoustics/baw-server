class DatasetsController < ApplicationController
  add_breadcrumb 'Home', :root_path

  # order matters for before_filter and load_and_authorize_resource!
  load_and_authorize_resource :project

  # this is necessary so that the ability has access to dataset.projects
  before_filter :build_project_dataset, only: [:new, :create]

  load_and_authorize_resource :dataset, through: :project

  before_filter :add_project_breadcrumb
  
  # GET /projects/:id/datasets
  # GET /projects/:id/datasets.json
  def index
    respond_to do |format|
      #format.html # index.html.erb
      format.json { render json: @datasets }
    end
  end

  # GET /projects/:id/datasets/1
  # GET /projects/:id/datasets/1.json
  def show
    respond_to do |format|
      format.html {
        add_breadcrumb @dataset.name, [@project, @dataset]
      }
      format.json { render json: @dataset }
    end
  end

  # GET /projects/:id/datasets/new
  # GET /projects/:id/datasets/new.json
  def new

    # need to do what cancan would otherwise do due to before_filter creating @dataset
    # see https://github.com/CanCanCommunity/cancancan/wiki/Controller-Authorization-Example
    current_ability.attributes_for(:new, Dataset).each do |key, value|
      @dataset.send("#{key}=", value)
    end
    @dataset.attributes = params[:dataset]
    authorize! :new, @dataset

    respond_to do |format|
      format.html {
        add_breadcrumb 'New Dataset'
      }
      format.json { render json: @dataset }
    end
  end

  # GET /projects/:id/datasets/1/edit
  def edit
    add_breadcrumb @dataset.name, [@project, @dataset]
    add_breadcrumb 'Edit'
  end

  # POST /projects/:id/datasets
  # POST /projects/:id/datasets.json
  def create

    # need to do what cancan would otherwise do due to before_filter creating @dataset
    # see https://github.com/CanCanCommunity/cancancan/wiki/Controller-Authorization-Example
    current_ability.attributes_for(:new, Dataset).each do |key, value|
      @dataset.send("#{key}=", value)
    end
    @dataset.attributes = params[:dataset]
    authorize! :create, @dataset

    respond_to do |format|
      if @dataset.save
        format.html { redirect_to [@project, @dataset], notice: 'Dataset was successfully created.' }
        format.json { render json: @dataset, status: :created, location: [@project, @dataset] }
      else
        format.html { render action: "new" }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /projects/:id/datasets/1
  # PUT /projects/:id/datasets/1.json
  def update
    respond_to do |format|
      if @dataset.update_attributes(params[:dataset])
        format.html { redirect_to [@project, @dataset], notice: 'Dataset was successfully updated.' }
        format.json { head :no_content }
      else
        format.html {
          add_breadcrumb @dataset.name, [@project, @dataset]
          render action: "edit"
        }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/:id/datasets/1
  # DELETE /projects/:id/datasets/1.json
  def destroy
    @dataset.destroy

    respond_to do |format|
      format.html { redirect_to project_datasets_url(@project) }
      format.json { head :no_content }
    end
  end

  private
  def add_project_breadcrumb
    add_breadcrumb 'Projects', projects_path
    add_breadcrumb @project.name, @project
  end

  def build_project_dataset
    @dataset = Dataset.new
    @dataset.project = @project
  end
end
