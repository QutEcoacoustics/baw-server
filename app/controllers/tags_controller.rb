class TagsController < ApplicationController

  load_and_authorize_resource :tag
  respond_to :json

  # GET /tags.json
  # GET /projects/1/sites/1/audio_recordings/1/audio_events/1/tags.json
  def index
    if params[:audio_event_id]
      @audio_event = AudioEvent.where(id: params[:audio_event_id]).first
      respond_with @audio_event.tags
    elsif params[:filter] #single tag, partial match
      respond_with Tag.where("text ILIKE '%?%'", params[:filter]).limit(20)
    else
      respond_with Tag.all
    end
  end

  # GET /tags/1
  # GET /tags/1.json
  def show
    respond_with @tag
  end

  # GET /tags/new
  # GET /tags/new.json
  def new
    render json: @tag.to_json(except: [:created_at, :creator_id, :updated_at, :updater_id] )
  end

  # POST /tags
  # POST /tags.json
  def create
    if @tag.save
       render json: @tag, status: :created
    else
      render json: @tag.errors, status: :unprocessable_entity
    end
  end

  private

  def tag_params
    params.require(:tag).permit(:is_taxanomic, :text, :type_of_tag, :retired, :notes)
  end
end
