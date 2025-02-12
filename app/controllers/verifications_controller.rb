# frozen_string_literal: true

# VerificationsController
class VerificationsController < ApplicationController
  include Api::ControllerHelper

  # GET /verifications
  # GET /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/verifications
  def index
    do_authorize_class
    get_audio_event

    @verifications, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      Verification,
      Verification.filter_settings
    )
    respond_index(opts)
  end

  # GET /verifications/:id
  # GET /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/verifications/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /verifications/new
  def new
    do_new_resource
    get_resource
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /verifications
  def create
    do_new_resource
    do_set_attributes(verification_params)

    do_authorize_instance

    if @verification.save
      respond_create_success(shallow_verification_url(@verification))
    else
      respond_change_fail
    end
  end

  # PUT/PATCH /verifications/:id
  def update
    do_load_resource
    do_authorize_instance

    if @verification.update(verification_update_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # Handled in Archivable
  # DELETE /verifications/:id

  # GET|POST /verifications/filter
  # GET|POST /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/verifications/filter
  def filter
    do_authorize_class
    get_audio_event

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      Verification,
      Verification.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def verification_params
    params.require(:verification).permit(
      :confirmed, :audio_event_id, :tag_id
    )
  end

  def verification_update_params
    params.require(:verification).permit(
      :confirmed
    )
  end

  def get_audio_event #rubocop:disable Naming/AccessorMethodName
    @audio_event = AudioEvent.find(params[:audio_event_id]) if params&.key?(:audio_event_id)
  end

  def list_permissions
    Access::ByPermission.audio_event_verifications(current_user, audio_event: @audio_event)
  end
end
