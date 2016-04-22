class AnalysisJobsItemsController < ApplicationController
  include Api::ControllerHelper

  #
  # This controller merges the old `analysis_controller` functionality
  # in with `analysis_jobs_items`. There was two choices here:
  #
  #  - keep the results separate from the job items
  #    e.g. /analysis_jobs/:analysis_job_id/audio_recordings    <- disk data
  #    and  /analysis_jobs/:analysis_job_id/analysis_jobs_items <- database
  #  - or, merge the resources
  #    e.g. /analysis_jobs/:analysis_job_id/audio_recordings
  #
  # We chose the later because:
  #
  # - The data, although stored in different mediums (disk and
  #   database) actually represent the same resource - audio recordings are
  #   processed by the job system; they have results
  # - Showing a list of audio recordings in the results is a problem
  #   that needed solving - if merged that problem gets solved automatically
  # - Less routes means less client complexity

  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/
  def index
    # TODO: double check permissions
    # - IF has access to audio recording
    # - IF analysis_job not deleted
    do_authorize_class

    @analysis_jobs_items, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_analysis_jobs_items,
        AnalysisJobItem,
        AnalysisJobItem.filter_settings
    )
    respond_index(opts)
  end

  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/
  def show
    # TODO: double check permissions
    # - IF has access to audio recording
    # - IF analysis_job not deleted
    do_load_resource
    do_authorize_instance



    respond_show
  end

  # Creation via API not needed at present time
  # GET /analysis_jobs/:analysis_job_id/audio_recordings/new
  # POST /analysis_jobs/:analysis_job_id/audio_recordings


  # PUT|PATCH /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id
  def update
    # TODO: double check permissions
    # - IFF has role :harvester
    do_load_resource
    do_authorize_instance

    if @analysis_jobs_item.update_attributes(analysis_jobs_item_update_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # GET|POST  /analysis_jobs/:analysis_job_id/audio_recordings/
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_analysis_jobs_items,
        AnalysisJobsItem,
        AnalysisJobsItem.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def analysis_job_update_params
    # Only status can be updated via API
    # Other properties are updated by the model/initial processing system
    params.require(:analysis_job_item).permit(:status)
  end

  def get_analysis_jobs_items
    Access::Query.analysis_jobs_items(current_user, Access::Core.levels_allow)
  end

end
