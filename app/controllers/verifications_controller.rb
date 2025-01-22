# frozen_string_literal: true

# VerificationsController
class VerificationsController < ApplicationController
  include Api::ControllerHelper

  # List (index) verifications
  # GET /verifications
  # GET /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/verifications
  def index
    do_authorize_class

    if params.include?(:audio_event_id)
      @audio_event = AudioEvent.find(params[:audio_event_id])
      authorize! :show, @audio_event # ANDREW TODO: - this line is in do_authorize class already?
      query = @audio_event.verifications
    else
      query = Verification.all
    end

    @verifications, opts = Settings.api_response.response_advanced(
      api_filter_params,
      query,
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

  # POST /verifications
  def create
    do_new_resource
    do_set_attributes(verification_params)
  end

  # PUT/PATCH /verifications/:id
  def update; end

  # DELETE /verifications/:id
  def destroy; end

  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Verification.all,
      Verification,
      Verification.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def verification_params
    params.require(:user).permit(
      :confirmed, :audio_event_id, :tag_id, :creator_id, :updater_id
    )
  end
end
