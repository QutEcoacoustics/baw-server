class JobsController < ApplicationController
  include Api::ControllerHelper

  # order matters for before_action and load_and_authorize_resource!
  load_and_authorize_resource :project

  # this is necessary so that the ability has access to job.dataset.projects
  before_action :build_project_job, only: [:new, :create]

  load_and_authorize_resource :job, through: :project

  # GET /jobs
  # GET /jobs.json
  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @jobs }
    end
  end

  # GET /jobs/1
  # GET /jobs/1.json
  def show
    respond_to do |format|
      format.html
      format.json { render json: @job }
    end
  end

  # GET /jobs/new
  # GET /jobs/new.json
  def new
    do_authorize!

    respond_to do |format|
      format.html
      format.json { render json: @job }
    end
  end

  # GET /jobs/1/edit
  def edit
  end

  # POST /jobs
  # POST /jobs.json
  def create

    attributes_and_authorize(job_params)

    respond_to do |format|
      if @job.save
        format.html { redirect_to @project, notice: 'Analysis job was successfully created.' }
        format.json { render json: @job, status: :created, location: @job }
      else
        format.html { render action: "new" }
        format.json { render json: @job.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /jobs/1
  # PUT /jobs/1.json
  def update
    respond_to do |format|
      if @job.update_attributes(job_params)
        format.html { redirect_to [@project, @job.dataset, @job], notice: 'Analysis job was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @job.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /jobs/1
  # DELETE /jobs/1.json
  def destroy
    @job.destroy
    add_archived_at_header(@job)

    respond_to do |format|
      format.html { redirect_to @project }
      format.json { head :no_content }
    end
  end

  private

  def build_project_job
    @dataset = Dataset.new
    @dataset.project = @project
    @job = Job.new
    @job.dataset = @dataset
  end

  def job_params
    params.require(:job).permit(
        :script_id, :dataset_id, :annotation_name,
        :name, :description, :script_settings)
  end
end
