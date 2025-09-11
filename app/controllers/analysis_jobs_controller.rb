# frozen_string_literal: true

class AnalysisJobsController < ApplicationController
  include Api::ControllerHelper

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
  # GET /analysis_jobs/system
  def show
    # customized - see below
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /analysis_jobs/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /analysis_jobs
  def create
    do_new_resource
    parameters = analysis_job_params(for_create: true)
    transform_scripts(parameters)

    do_set_attributes(parameters)
    do_authorize_instance

    if @analysis_job.save
      # now create and enqueue job items (which updates status attributes again)
      # needs to be called after save as it makes use of the analysis_job id.
      # @type [AnalysisJob]
      @analysis_job.process!

      respond_create_success
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /analysis_jobs/1
  # PUT|PATCH /analysis_jobs/system
  def update
    # customized - see below
    do_load_resource
    do_authorize_instance

    parameters = analysis_job_params(for_create: false)

    if @analysis_job.update(parameters)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /analysis_jobs/1
  # Handled in Archivable
  # Using callback defined in Archivable
  before_destroy do
    # only allow deleting from suspended or completed states
    can_delete = @analysis_job.completed? || @analysis_job.suspended?

    # also allow from processing, since we can suspend
    if @analysis_job.processing? && @analysis_job.may_suspend?
      can_delete = true
      @analysis_job.suspend!
    end

    next if can_delete

    respond_error(:conflict, "Cannot be deleted while `overall_status` is `#{@analysis_job.overall_status}`")
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

  # PUT|POST /analysis_jobs/:analysis_job_id/retry
  # PUT|POST /analysis_jobs/:analysis_job_id/resume
  # PUT|POST /analysis_jobs/:analysis_job_id/suspend
  # PUT|POST /analysis_jobs/:analysis_job_id/amend
  def invoke
    # allow the API to transition this analysis job to a new state.
    # Used for suspending, resuming, and retrying an analysis_job
    do_invoke
  end

  private

  def invoke_retry
    @analysis_job.retry!
  end

  def invoke_resume
    @analysis_job.resume!
  end

  def invoke_suspend
    @analysis_job.suspend!
  end

  def invoke_amend
    raise CustomErrors::UnprocessableEntityError, 'Cannot amend a non-ongoing job' unless @analysis_job.ongoing?

    @analysis_job.amend!
  end

  def system_job?
    params[:id].to_s.downcase == AnalysisJob::SYSTEM_JOB_ID
  end

  # load the current resource.
  # Patched to handle the system route parameter.
  # Warning: will fail to load custom properties for filter requests.
  def do_load_resource
    return set_resource(AnalysisJob.latest_system_analysis!) if system_job?

    super
  end

  def analysis_job_params(for_create: true)
    # Only name and description can be updated via API.
    # Other properties are updated by the processing system.

    permitted = [
      :name,
      :description,
      :ongoing
    ]

    permitted << :system_job if for_create
    permitted << :project_id if for_create
    permitted << { scripts: [:script_id, :custom_settings, :event_import_minimum_score] } if for_create
    permitted << { filter: {} } if for_create

    params.require(:analysis_job).permit(*permitted)
  end

  # accepts_nested_attributes_for is ugly (you must have the _attributes suffix)
  # and it also does too much (deletion and modification of existing records).
  # We have a simpler use case - we only accept existing script records and
  # only accept setting the relation on job creation.
  def transform_scripts(parameters)
    scripts = parameters.delete(:scripts)

    scripts&.each do |script|
      ajs = AnalysisJobsScript.new(script_id: script[:script_id])
      ajs.custom_settings = script[:custom_settings] if script.key?(:custom_settings)
      ajs.event_import_minimum_score = script[:event_import_minimum_score] if script.key?(:event_import_minimum_score)
      @analysis_job.analysis_jobs_scripts << ajs
    end
  end

  def get_analysis_jobs
    Access::ByPermission.analysis_jobs(current_user)
  end
end
