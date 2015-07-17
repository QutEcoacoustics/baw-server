class AnalysisJobsController < ApplicationController
  include Api::ControllerHelper

  # order matters for before_action and load_and_authorize_resource!
  load_and_authorize_resource :analysis_job

  # this is necessary so that the ability has access to job.dataset.projects
  before_action :build_analysis_job, only: [:new, :create]

  # GET /analysis_job
  # GET /analysis_job.json
  def index
    @analysis_jobs, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_analysis_jobs,
        AnalysisJob,
        AnalysisJob.filter_settings
    )
    respond_index(opts)
  end

  # GET /analysis_job/1
  # GET /analysis_job/1.json
  def show
    respond_show
  end

  # GET /analysis_job/new
  # GET /analysis_job/new.json
  def new
    do_authorize!

    respond_show
  end

  # POST /analysis_job
  # POST /analysis_job.json
  def create
    attributes_and_authorize(analysis_jobs_params)

    # This may need to be async depending on how fast it runs
    @analysis_job.enqueue_work(current_user)

    if @analysis_job.save
      respond_create_success(analysis_job_url(@analysis_job))
    else
      respond_change_fail
    end
  end

  # PUT /analysis_job/1
  # PUT /analysis_job/1.json
  def update
    if @analysis_job.update_attributes(analysis_jobs_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /analysis_job/1
  # DELETE /analysis_job/1.json
  def destroy
    @analysis_job.destroy
    add_archived_at_header(@analysis_job)
    respond_destroy
  end

  # POST /analysis_jobs/filter.json
  # GET /analysis_jobs/filter.json
  def filter
    authorize! :filter, AnalysisJob
    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_analysis_jobs,
        AnalysisJob,
        AnalysisJob.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def build_analysis_job
    @analysis_job = AnalysisJob.new
  end

  def analysis_jobs_params
    params.require(:job).permit(
        :script_id, :saved_search_id,
        :name,
        :description,
        :annotation_name,
        :custom_settings,
        :started_at,
        :overall_status,
        :overall_status_modified_at,
        :overall_progress,
        :overall_progress_modified_at,
        :overall_count,
        :overall_duration_seconds)
  end

  def get_analysis_jobs
    Access::Query.analysis_jobs(current_user, Access::Core.levels_allow)
  end

end
