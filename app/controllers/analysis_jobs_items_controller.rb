# frozen_string_literal: true

class AnalysisJobsItemsController < ApplicationController
  include Api::ControllerHelper
  include Api::AnalysisJobsItemsShared

  # This controller merges the old `analysis_controller` functionality in with `analysis_jobs_items`. There were two
  # choices here:
  #
  #  - keep the results separate from the job items
  #    e.g. /analysis_jobs/:analysis_job_id/results/:audio_recording_id/[/:path]                    <- disk data
  #    and  /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id                    <- database
  #  - or, merge the resources
  #    e.g. /analysis_jobs/:analysis_job_id/audio_recordings
  #
  # We chose the former because:
  #
  # - Analysis workers need to poll the #show method. Requiring disk access in such cases slows down the response
  #   and introduces disk based dependencies for a status API.
  #
  # Warning: this controller does not expose any AnalysisJobsItems by the `id` primary key!

  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/
  def index
    do_authorize_class
    do_get_opts

    do_get_analysis_job
    @analysis_jobs_items, opts = Settings.api_response.response_advanced(
      api_filter_params,
      get_query,
      AnalysisJobsItem,
      AnalysisJobsItem.filter_settings(@is_system_job)
    )

    respond_index(opts)
  end

  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/
  def show
    do_get_opts

    do_load_resource
    do_authorize_instance

    respond_show
  end

  # Creation/deletion via API not needed at present time.
  # May be needed if we designate saved search execution to a worker.
  # GET /analysis_jobs/:analysis_job_id/audio_recordings/new
  # POST /analysis_jobs/:analysis_job_id/audio_recordings
  # DELETE /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id

  # PUT|PATCH /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id
  def update
    do_get_opts

    if @is_system_job
      raise CustomErrors::MethodNotAllowedError.new(
        'Cannot update a system job\'s analysis jobs items',
        [:post, :put, :patch, :delete]
      )
    end

    do_load_resource
    do_get_analysis_job
    do_authorize_instance

    parameters = analysis_jobs_item_update_params
    desired_state = parameters[:status].to_sym

    client_cancelled = desired_state == :cancelled
    should_cancel = @analysis_jobs_item.may_confirm_cancel?(desired_state)
    valid_transition = @analysis_jobs_item.may_transition_to_state(desired_state)

    if valid_transition
      @analysis_jobs_item.transition_to_state!(desired_state)
    elsif should_cancel
      @analysis_jobs_item.confirm_cancel(desired_state)
    end

    saved = @analysis_jobs_item.save

    if saved
      # update progress statistics and check if job has been completed
      @analysis_job.check_progress
    end

    if should_cancel && !client_cancelled && saved
      # If someone tried to :cancelling-->:working instead of :cancelling-->:cancelled then it is an error
      # However if client :cancelled when we expected :cancelling-->:cancelled then well behaved
      respond_error(
        :unprocessable_entity,
        "This entity has been cancelled - can not set new state to `#{desired_state}`"
      )

    elsif !valid_transition
      respond_error(
        :unprocessable_entity,
        "Cannot transition from `#{@analysis_jobs_item.status}` to `#{desired_state}`"
      )
    elsif saved
      respond_show
    else
      respond_change_fail
    end
  end

  # GET|POST  /analysis_jobs/:analysis_job_id/audio_recordings/
  def filter
    do_authorize_class
    do_get_opts

    do_get_analysis_job
    @analysis_jobs_items, opts = Settings.api_response.response_advanced(
      api_filter_params,
      get_query,
      AnalysisJobsItem,
      AnalysisJobsItem.filter_settings(@is_system_job)
    )

    respond_index(opts)
  end

  private

  SYSTEM_JOB_ID = AnalysisJobsItem::SYSTEM_JOB_ID

  def analysis_jobs_item_update_params
    # Only status can be updated via API
    # Other properties are updated by the model/initial processing system
    params.require(:analysis_jobs_item).permit(:status)
  end
end
