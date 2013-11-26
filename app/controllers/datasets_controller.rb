class DatasetsController < ApplicationController
  add_breadcrumb 'home', :root_path

  load_and_authorize_resource :project
  before_filter :build_project_dataset, only: [:new, :create] # this is necessary so that the ability has access to site.projects
  load_and_authorize_resource :dataset, through: :project

  before_filter :add_project_breadcrumb
  
  # GET /projects/:id/datasets
  # GET /projects/:id/datasets.json
  def index
    @datasets = @project.datasets

    respond_to do |format|
      #format.html # index.html.erb
      format.json { render json: @datasets }
    end
  end

  # GET /projects/:id/datasets/1
  # GET /projects/:id/datasets/1.json
  def show
    @dataset = @project.datasets.find(params[:id])

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
    @dataset = Dataset.new

    respond_to do |format|
      format.html {
        add_breadcrumb 'New Dataset'
      }
      format.json { render json: @dataset }
    end
  end

  # GET /projects/:id/datasets/1/edit
  def edit
    @dataset = @project.datasets.find(params[:id])
    add_breadcrumb @dataset.name, [@project, @dataset]
    add_breadcrumb 'Edit'
  end

  # POST /projects/:id/datasets
  # POST /projects/:id/datasets.json
  def create
    @dataset = Dataset.new(params[:dataset])
    @dataset.project = @project

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
    @dataset = Dataset.find(params[:id])
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
    @dataset = Dataset.find(params[:id])
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
