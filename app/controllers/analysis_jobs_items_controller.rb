class AnalysisJobsItemsController < ApplicationController
  include Api::ControllerHelper

  #
  # This controller merges the old `analysis_controller` functionality in with `analysis_jobs_items`. There were two
  # choices here:
  #
  #  - keep the results separate from the job items
  #    e.g. /analysis_jobs/:analysis_job_id/audio_recordings    <- disk data
  #    and  /analysis_jobs/:analysis_job_id/analysis_jobs_items <- database
  #  - or, merge the resources
  #    e.g. /analysis_jobs/:analysis_job_id/audio_recordings
  #
  # We chose the later because:
  #
  # - The data, although stored in different mediums (disk and database) actually represent the same resource -
  #   audio recordings are processed by the job system; thus it is natural that they have results.
  # - Showing a list of audio recordings in the results is a problem that needed solving - if merged that problem gets
  #   solved automatically
  # - Less routes means less client complexity
  #
  # System jobs are run automatically by the system. They don't have analysis_jobs_item records in the database. Rather
  # we proxy requests to audio_recordings table.

  # Warning: this controller does not expose any AnalysisJobsItems by the `id` primary key!

  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/
  def index
    # TODO: double check permissions
    # - IF has access to audio recording
    # - IF analysis_job not deleted
    do_authorize_class
    get_opts
    get_analysis_job


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

    get_opts

    do_load_resource


    do_authorize_instance

    # TODO process results

    respond_show
  end

  # Creation/deletion via API not needed at present time.
  # May be needed if we designate saved search execution to a worker.
  # GET /analysis_jobs/:analysis_job_id/audio_recordings/new
  # POST /analysis_jobs/:analysis_job_id/audio_recordings
  # DELETE /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id

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
    get_opts
    get_analysis_job

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_analysis_jobs_items,
        AnalysisJobsItem,
        AnalysisJobsItem.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  #
  # 'system' actions - matched via route
  #

  SYSTEM_JOB_ID = AnalysisJobsController.SYSTEM_JOB_ID

  # GET|HEAD /analysis_jobs/system/audio_recordings/
  def system_index
    do_authorize_class
    get_opts

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_virtual_analysis_jobs_items,
        AudioRecording,
        AnalysisJobsItem.filter_settings # TODO
    )

    # TODO transform response

    respond_filter(filter_response, opts)
  end

  # GET|HEAD /analysis_jobs/system/audio_recordings/:audio_recording_id
  def system_show
    get_opts

    audio_recording = AnalysisJob.find(@analysis_job_id)
# TODO transform response

    do_authorize_instance

# TODO process results

    respond_show

  end

  # PUT|PATCH /analysis_jobs/system/audio_recordings/:audio_recording_id
  def system_update
    fail MethodNotAllowedError.new('Cannot update a system job\'s analysis jobs items', [:put, :patch])
  end

  # GET|POST /analysis_jobs/system/audio_recordings/filter
  def system_filter
    do_authorize_class
    get_opts

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_virtual_analysis_jobs_items,
        AudioRecording,
        AnalysisJobsItem.filter_settings # TODO
    )

    # TODO transform response

    respond_filter(filter_response, opts)
  end

  private


  def analysis_jobs_item_update_params
    # Only status can be updated via API
    # Other properties are updated by the model/initial processing system
    params.require(:analysis_jobs_item).permit(:status)
  end

  def get_opts
    @analysis_job_id = params[:analysis_job_id]
    @audio_recording_id = params[:audio_recording_id]
  end

  def get_analysis_job
    @analysis_job = AnalysisJob.find(@analysis_job_id)
  end

  def get_analysis_jobs_items
    Access::Query.analysis_jobs_items(@analysis_job, current_user)
  end

  def get_virtual_analysis_jobs_items
    Access::Query.audio_recordings(current_user)
  end

  def do_load_resource
    resource = AnalysisJobsItem.find_by(
        analysis_job_id: @analysis_job_id,
        audio_recording_id: @audio_recording_id
    )
    set_resource(resource)
  end


end
