# frozen_string_literal: true

class TaggingsController < ApplicationController
  include Api::ControllerHelper

  # GET /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings
  def index
    do_authorize_class
    get_audio_recording
    get_audio_event
    do_authorize_instance(:show, @audio_event)

    @taggings, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_events_tags(current_user, Access::Core.levels, @audio_event),
      Tagging,
      Tagging.filter_settings
    )
    respond_index(opts)
  end

  # GET /user_accounts/:user_id/taggings
  def user_index
    do_authorize_class
    @user = User.find(params[:user_id])
    do_authorize_instance(:show, @user)

    @taggings, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_events_tags(current_user).where(creator: @user),
      Tagging,
      Tagging.filter_settings
    )
    respond_index(opts)
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id
  def show
    do_load_resource
    get_audio_recording
    get_audio_event
    do_authorize_instance
    do_authorize_instance(:show, @audio_event)

    respond_show
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/new
  def new
    do_new_resource
    do_set_attributes
    get_audio_recording
    get_audio_event
    do_authorize_instance

    respond_show
  end

  # POST /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/
  def create
    do_new_resource
    do_set_attributes(tagging_params)
    get_audio_recording
    get_audio_event
    do_authorize_instance

    if tagging_params && tagging_params[:tag_attributes] && tagging_params[:tag_attributes][:text]
      tag = Tag.where(text: tagging_params[:tag_attributes][:text]).first
      if tag.blank?
        # if the tag with the name does not already exist, create it via tag_attributes
        tag = Tag.new(tagging_params[:tag_attributes])
        render json: tag.errors, status: :unprocessable_entity and return unless tag.save
      end
      @tagging.tag = tag
    else
      # tag attributes are directly available
      @tagging = Tagging.new(tagging_params)
    end

    @tagging.audio_event = @audio_event

    if @tagging.save
      respond_create_success(audio_recording_audio_event_tagging_path(@audio_recording, @audio_event, @tagging))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id
  def update
    do_load_resource
    get_audio_recording
    get_audio_event
    do_authorize_instance

    if @tagging.update(tagging_params)
      respond_show
    else
      respond_change_fail
    end
  end

  ## DELETE /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id
  def destroy
    do_load_resource
    do_authorize_instance

    @tagging.destroy

    respond_destroy
  end

  # GET|POST /taggings/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_events_tags(current_user),
      Tagging,
      Tagging.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  # override resource name
  def resource_name
    'tagging'
  end

  def get_audio_recording
    @audio_recording = AudioRecording.find(params[:audio_recording_id])
  end

  def get_audio_event
    @audio_event = AudioEvent.find(params[:audio_event_id])

    # avoid the same project assigned more than once to a site
    @tagging.audio_event = @audio_event if defined?(@tagging) && @tagging.audio_event.blank?
  end

  def tagging_params
    params.require(:tagging).permit(:audio_event_id, :tag_id, tag_attributes: [:is_taxanomic, :text, :type_of_tag, :retired, :notes])
  end
end
