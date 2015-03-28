class TagsController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource

  # GET /tags.json
  # GET /projects/1/sites/1/audio_recordings/1/audio_events/1/tags.json
  def index

    respond_to do |format|
      format.json {
        if params[:audio_event_id]
          @audio_event = AudioEvent.where(id: params[:audio_event_id]).first
          render json: @audio_event.tags.to_json(only: Tag.filter_settings[:render_fields])
        elsif params[:filter] #single tag, partial match
          render json: Tag.where("text ILIKE '%?%'", params[:filter]).limit(20).to_json(only: Tag.filter_settings[:render_fields])
        else
          render json: Tag.all.to_json(only: Tag.filter_settings[:render_fields])
        end
      }
    end

  end

  # GET /tags/1.json
  def show
    respond_show
  end

  # GET /tags/new.json
  def new
    respond_show
  end

  # POST /tags.json
  def create
    if @tag.save
      respond_create_success
    else
      respond_change_fail
    end
  end

  # POST /sites/filter.json
  # GET /sites/filter.json
  def filter
    authorize! :filter, Tag
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
    params.require(:tag).permit(:is_taxanomic, :text, :type_of_tag, :retired, :notes)
  end
end
