class DatasetsController < ApplicationController
  include Api::ControllerHelper

  # order matters for before_action and load_and_authorize_resource!
  load_and_authorize_resource :project

  # this is necessary so that the ability has access to dataset.projects
  before_action :build_project_dataset, only: [:new, :create]

  load_and_authorize_resource :dataset, through: :project
  
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
      format.html
      format.json { render json: @dataset }
    end
  end

  # GET /projects/:id/datasets/new
  # GET /projects/:id/datasets/new.json
  def new

    do_authorize!

    respond_to do |format|
      format.html
      format.json { render json: @dataset }
    end
  end

  # GET /projects/:id/datasets/1/edit
  def edit
  end

  # POST /projects/:id/datasets
  # POST /projects/:id/datasets.json
  def create

    attributes_and_authorize(dataset_params)

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
      if @dataset.update_attributes(dataset_params)
        format.html { redirect_to [@project, @dataset], notice: 'Dataset was successfully updated.' }
        format.json { head :no_content }
      else
        format.html {
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

  def build_project_dataset
    @dataset = Dataset.new
    @dataset.project = @project
  end

  def dataset_params
    params.require(:dataset).permit(
        :description, :end_date, :end_time,
        :filters, :name,
        :number_of_samples, :number_of_tags,
        :start_date, :start_time, {types_of_tags: [] },
        {site_ids: []}, :tag_text_filters,
        :tag_text_filters_list,
        :has_time, :has_date)
  end
end
