class JobsController < ApplicationController
  add_breadcrumb 'Home', :root_path

  # order matters for before_filter and load_and_authorize_resource!
  load_and_authorize_resource :project

  # this is necessary so that the ability has access to job.dataset.projects
  before_filter :build_project_job, only: [:new, :create]

  load_and_authorize_resource :job, through: :project

  before_filter :add_project_breadcrumb

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
      format.html {
        add_breadcrumb "Dataset: #{@job.dataset.name}", project_dataset_path(@project, @job.dataset)
        add_breadcrumb "Job: #{@job.name}", [@project, @job]
      }
      format.json { render json: @job }
    end
  end

  # GET /jobs/new
  # GET /jobs/new.json
  def new
    # need to do what cancan would otherwise do due to before_filter creating @job
    # see https://github.com/CanCanCommunity/cancancan/wiki/Controller-Authorization-Example
    current_ability.attributes_for(:new, Job).each do |key, value|
      @job.send("#{key}=", value)
    end
    @job.attributes = params[:job]
    authorize! :new, @job

    respond_to do |format|
      format.html {
        add_breadcrumb 'New Script'
      }
      format.json { render json: @job }
    end
  end

  # GET /jobs/1/edit
  def edit
    add_breadcrumb "Dataset: #{@job.dataset.name}", project_dataset_path(@project, @job.dataset)
    add_breadcrumb "Job: #{@job.name}", [@project,  @job.dataset, @job]
    add_breadcrumb 'Edit', edit_project_job_path(@project, @job)
  end

  # POST /jobs
  # POST /jobs.json
  def create

    # need to do what cancan would otherwise do due to before_filter creating @job
    # see https://github.com/CanCanCommunity/cancancan/wiki/Controller-Authorization-Example
    current_ability.attributes_for(:new, Job).each do |key, value|
      @job.send("#{key}=", value)
    end
    @job.attributes = params[:job]
    authorize! :create, @job

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
      if @job.update_attributes(params[:job])
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

    respond_to do |format|
      format.html { redirect_to @project }
      format.json { head :no_content }
    end
  end

  private

  def add_project_breadcrumb
    add_breadcrumb 'Projects', projects_path
    add_breadcrumb @project.name, @project
  end

  def build_project_job
    @dataset = Dataset.new
    @dataset.project = @project
    @job = Job.new
    @job.dataset = @dataset
  end
end
