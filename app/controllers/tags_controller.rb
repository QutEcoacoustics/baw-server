# frozen_string_literal: true

class TagsController < ApplicationController
  include Api::ControllerHelper

  # GET /tags
  # GET /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags
  def index
    do_authorize_class

    if params.include?(:audio_event_id)
      @audio_event = AudioEvent.find(params[:audio_event_id])
      authorize! :show, @audio_event
      query = @audio_event.tags
    else
      query = Tag.all
    end

    @tags, opts = Settings.api_response.response_advanced(
      api_filter_params,
      query,
      Tag,
      Tag.filter_settings
    )
    respond_index(opts)
  end

  # GET /tags/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /tags/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_show
  end

  # POST /tags
  def create
    do_new_resource
    do_set_attributes(tag_params)
    do_authorize_instance

    if @tag.save
      respond_create_success
    else
      respond_change_fail
    end
  end

  # GET|POST /tags/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Tag.all,
      Tag,
      Tag.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def tag_params
    sanitize_associative_array(:tag, :notes)

    params.require(:tag).permit(:is_taxonomic, :text, :type_of_tag, :retired, :notes, notes: {})
  end
end
