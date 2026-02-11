# frozen_string_literal: true

class AudioEventsController < ApplicationController
  include Api::ControllerHelper

  skip_authorization_check only: [:show]

  def should_skip_bullet?
    # Bullet raises a  false positive here... our custom fields load an attribute from the database, but if attribute
    # has the same name as the association, bullet gets confused and thinks we should have eager loaded the association
    # TODO: fix, it's probably bad practice to load custom fields that can clash with active record attributes
    action_sym == :filter
  end

  # GET /audio_recordings/:audio_recording_id/audio_events
  def index
    do_authorize_class
    get_audio_recording

    @audio_events, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_events(current_user, audio_recording: @audio_recording),
      AudioEvent,
      AudioEvent.filter_settings
    )
    respond_index(opts)
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/:id
  def show
    # allow logged-in users to access reference audio events
    # they would otherwise not have access to

    request_params = audio_event_show_params.to_h
    request_params[:audio_event_id] = request_params[:id]

    @audio_recording = auth_custom_audio_recording(request_params)
    @audio_event = auth_custom_audio_event(request_params, @audio_recording)

    respond_show
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/new
  def new
    do_new_resource
    get_audio_recording
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /audio_recordings/:audio_recording_id/audio_events
  def create
    do_new_resource
    do_set_attributes(audio_event_params)

    get_audio_recording
    do_authorize_instance

    if @audio_event.save!
      respond_create_success(audio_recording_audio_event_path(@audio_recording, @audio_event))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /audio_recordings/:audio_recording_id/audio_events/:id
  def update
    do_load_resource
    get_audio_recording
    do_authorize_instance

    if @audio_event.update(audio_event_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /audio_recordings/:audio_recording_id/audio_events/:id
  # Handled in Archivable
  # Using callback defined in Archivable
  before_destroy do
    get_audio_recording
  end

  # GET|POST /audio_events/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_events(current_user),
      AudioEvent,
      AudioEvent.filter_settings
    )

    respond_filter(filter_response, opts)
  end

  private

  def audio_event_params
    params.require(:audio_event).permit(
      :audio_recording_id,
      :start_time_seconds, :end_time_seconds,
      :low_frequency_hertz, :high_frequency_hertz,
      :is_reference,
      :channel,
      # AT 2021: disabled. Nested associations are extremely complex,
      # and as far as we are aware, they are not used anywhere in production
      # TODO: remove on passing test suite
      #tags_attributes: [:is_taxonomic, :text, :type_of_tag, :retired, :notes],
      tag_ids: []
    )
  end

  def audio_event_index_params
    params.permit(
      :start_offset, :end_offset,
      :format, :audio_recording_id, audio_event: {}
    )
  end

  def audio_event_show_params
    params.permit(:id, :project_id, :site_id, :format, :audio_recording_id, audio_event: {})
  end

  def get_audio_recording
    @audio_recording = AudioRecording.find(params[:audio_recording_id])

    # avoid the same project assigned more than once to a site
    @audio_event.audio_recording = @audio_recording if defined?(@audio_event) && @audio_event.audio_recording.blank?
  end
end
