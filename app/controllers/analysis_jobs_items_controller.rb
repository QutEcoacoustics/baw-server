# frozen_string_literal: true

# Controller for analysis jobs items.
# For analysis jobs results see AnalysisJobsResultsController
class AnalysisJobsItemsController < ApplicationController
  include Api::ControllerHelper

  # analysis jobs items are exposed from two endpoints:
  #  - /analysis_jobs/:analysis_job_id/results
  #     - for results
  #     - reads from disk
  #  - /analysis_jobs/:analysis_job_id/items
  #    - for items as a normal resource
  #    - db only, no disk access
  #    - handles jobs status updates
  #
  # This controller handles the second endpoint.

  # GET|HEAD /analysis_jobs/:analysis_job_id/items/
  def index
    do_authorize_class
    get_analysis_job(for_list_endpoint: true)

    @analysis_jobs_items, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      AnalysisJobsItem,
      AnalysisJobsItem.filter_settings
    )

    respond_index(opts)
  end

  # GET|HEAD /analysis_jobs/:analysis_job_id/items/:id/
  def show
    do_load_resource
    get_analysis_job(for_list_endpoint: false)
    do_authorize_instance

    respond_show
  end

  # PUT|PATCH /analysis_jobs/:analysis_job_id/items/:id
  # Currently no fields supported for update.
  #def update
  #end

  # GET|POST  /analysis_jobs/:analysis_job_id/items/filter
  def filter
    do_authorize_class
    get_analysis_job(for_list_endpoint: true)

    @analysis_jobs_items, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      AnalysisJobsItem,
      AnalysisJobsItem.filter_settings
    )

    respond_index(opts)
  end

  # PUT|POST /analysis_jobs/:analysis_job_id/items/:id/working
  # PUT|POST /analysis_jobs/:analysis_job_id/items/:id/finish
  def invoke
    do_invoke
  end

  def self.resolve_job_from_route_parameter(analysis_job_id)
    # replace the special route parameter 'system' with the latest system job
    # We use with deleted here because we always need to be able to load
    # AnalysisJobsItem even if the parent AnalysisJob has been deleted.
    if analysis_job_id.to_s.downcase == AnalysisJob::SYSTEM_JOB_ID
      AnalysisJob.with_discarded.latest_system_analysis!
    else
      AnalysisJob.with_discarded.find(analysis_job_id.to_i)
    end
  end

  private

  def invoke_finish
    # graceful noop if current state is desired state - allows for webhooks
    # that are fired multiple times to not cause issues
    @analysis_jobs_item.transition_finish! if @analysis_jobs_item.may_finish?
  end

  def invoke_working
    # graceful noop if current state is desired state - allows for webhooks
    # that are fired multiple times to not cause issues
    @analysis_jobs_item.work! if @analysis_jobs_item.may_work?
  end

  def analysis_jobs_item_update_params
    # no fields can be updated via API
  end

  def get_analysis_job(for_list_endpoint: false)
    # two cases:
    # 1. nested list (:analysis_job_id)
    # 2. nested show (:analysis_job_id, :id)
    @analysis_job = AnalysisJobsItemsController.resolve_job_from_route_parameter(params[:analysis_job_id])

    # we only need to check ids match in case 2: nested show
    return if for_list_endpoint
    return if @analysis_job.id == @analysis_jobs_item.analysis_job_id

    raise CustomErrors::RoutingArgumentError,
      'analysis_jobs_item_id does not belong to the analysis_job_id in route'
  end

  def list_permissions
    Access::ByPermission.analysis_jobs_items(@analysis_job, current_user)
  end
end
