class AnalysisJobsController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource :analysis_job, except: [:filter]

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

  # GET /analysis_job/1.json
  def show
    respond_show
  end

  # GET /analysis_job/new.json
  def new
    respond_show
  end

  # POST /analysis_job.json
  def create
    if @analysis_job.save

      # once analysis job is successfully saved,
      # generate the job items specified by the analysis job
      # TODO This may need to be an async operation itself depending on how fast it runs
      #sub_items = @analysis_job.generate_items(current_user)
      # and enqueue the job items
      # so that the async processing can begin
      #enqueue_result = @analysis_job.enqueue_work(current_user, sub_items)

      respond_create_success
    else
      respond_change_fail
    end
  end

  # PUT /analysis_job/1.json
  def update
    if @analysis_job.update_attributes(analysis_job_update_params)
      respond_show
    else
      respond_change_fail
    end
  end

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

  def analysis_job_create_params
    # When Analysis jobs are created, they must have
    # a script, saved search, name, and custom settings.
    # May have a description.
    params.require(:job).permit(
        :script_id,
        :saved_search_id,
        :name,
        :custom_settings,
        :description)
  end

  def analysis_job_update_params
    # Only name and description can be updated via API.
    # Other properties are updated by the processing system.
    params.require(:job).permit(:name, :description)
  end

  def get_analysis_jobs
    Access::Query.analysis_jobs(current_user, Access::Core.levels_allow)
  end

end
