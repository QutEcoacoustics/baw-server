class TagsController < ApplicationController

  #load_and_authorize_resource :project
  #load_resource :audio_event
  load_and_authorize_resource :tag
  respond_to :json

  # GET /tags.json
  # GET /projects/1/sites/1/audio_recordings/1/audio_events/1/tags.json
  def index
    if params[:audio_event_id]
      @audio_event = AudioEvent.find(params[:audio_event_id])
      respond_with @audio_event.tags
    else
      respond_with Tag.all
    end
  end

  # GET /tags/1
  # GET /tags/1.json
  def show
    respond_with Tag.find(params[:id])
  end

  # GET /tags/new
  # GET /tags/new.json
  def new
    @tag = Tag.new
    render json: @tag.to_json(except: [:created_at, :creator_id, :updated_at, :updater_id] )
  end

  # POST /tags
  # POST /tags.json
  def create
    @tag = Tag.new(params[:tag])

    if @tag.save
       render json: @tag, status: :created
    else
      render json: @tag.errors, status: :unprocessable_entity
    end
  end

  # PUT /tags/1
  # PUT /tags/1.json
  def update
    respond_with Tag.update(params[:id], params[:tag])
  end

  # DELETE /tags/1
  # DELETE /tags/1.json
  def destroy
    @tag = Tag.find(params[:id])
    @tag.destroy

    respond_to do |format|
      format.json { no_content_as_json }
    end
  end
end
