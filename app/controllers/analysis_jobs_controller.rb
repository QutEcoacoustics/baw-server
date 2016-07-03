class AnalysisJobsController < ApplicationController
  include Api::ControllerHelper

  SYSTEM_JOB_ID = AnalysisJobsItem::SYSTEM_JOB_ID

  # GET /analysis_jobs
  def index
    do_authorize_class

    @analysis_jobs, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_analysis_jobs,
        AnalysisJob,
        AnalysisJob.filter_settings
    )
    respond_index(opts)
  end

  # GET /analysis_jobs/1
  def show
    return system_show if is_system?

    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /analysis_jobs/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_show
  end

  # POST /analysis_jobs
  def create
    do_new_resource
    do_set_attributes(analysis_job_create_params)
    do_authorize_instance

    if @analysis_job.save

      # now create and enqueue job items (which updates status attributes again)
      # needs to be called after save as it makes use of the analysis_job id.
      @analysis_job.begin_work(current_user)

      respond_create_success
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /analysis_jobs/1
  def update
    return system_mutate if is_system?

    do_load_resource
    do_authorize_instance

    if @analysis_job.update_attributes(analysis_job_update_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /analysis_jobs/1
  def destroy
    return system_mutate if is_system?

    do_load_resource
    do_authorize_instance

    @analysis_job.destroy
    add_archived_at_header(@analysis_job)

    # TODO: delete pending analysis jobs from worker message queue
    # TODO: change all pending analysis_job_items to :cancelled

    respond_destroy
  end

  # GET|POST /analysis_jobs/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_analysis_jobs,
        AnalysisJob,
        AnalysisJob.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  # GET|HEAD /analysis_jobs/system
  def system_show
    fail NotImplementedError.new
  end

  # PUT|PATCH|DELETE /analysis_jobs/system
  def system_mutate
    fail CustomErrors::MethodNotAllowedError.new('Cannot update a system job', [:post, :put, :patch, :delete])
  end

  def is_system?
    params[:id] == 'system'
  end

  def analysis_job_create_params
    # When Analysis jobs are created, they must have
    # a script, saved search, name, and custom settings.
    # May have a description.
    params.require(:analysis_job).permit(
        :script_id,
        :saved_search_id,
        :name,
        :custom_settings,
        :description)
  end

  def analysis_job_update_params
    # Only name and description can be updated via API.
    # Other properties are updated by the processing system.
    params.require(:analysis_job).permit(:name, :description)
  end

  def get_analysis_jobs
    Access::ByPermission.analysis_jobs(current_user, Access::Core.levels)
  end
end
