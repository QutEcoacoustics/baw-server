class TaggingsController < ApplicationController

  load_and_authorize_resource :audio_recording
  load_resource :audio_event
  load_resource :tagging
  respond_to :json

  # GET /tags
  # GET /tags.json
  def index
    if @audio_event
      render json: @audio_event.taggings.to_json(include: [:tag ])
    else
      render json: Tagging.all.to_json(include: [:tag ])
    end
  end

  # GET /tags/1
  # GET /tags/1.json
  def show
    respond_with Tagging.find(params[:id])
  end

  # GET /tags/new
  # GET /tags/new.json
  def new
    respond_with Tagging.new
  end

  # POST /tags
  # POST /tags.json
  def create
    # @audio_recording, @audio_event and @tagging are initialised/preloaded by load_resource/load_and_authorize_resource
    if params[:tagging] && params[:tagging][:tag_attributes] && params[:tagging][:tag_attributes][:text]
      @tagging = Tagging.new
      @tag = Tag.find_by_text(params[:tagging][:tag_attributes][:text])
      if @tag.blank?
        # if the tag with the name does not already exist, create it via tag_attributes
        @tag = Tag.new(params[:tagging][:tag_attributes])
        unless @tag.save
          render json: @tag.errors, status: :unprocessable_entity and return
        end
      end
      @tagging.tag = @tag
    else
      # tag attributes are directly available
      @tagging = Tagging.new(params[:tagging])
    end

    @tagging.audio_event = @audio_event

    if @tagging.save
      render json: @tagging, status: :created
    else
      render json: @tagging.errors, status: :unprocessable_entity
    end
  end

  # PUT /tags/1
  # PUT /tags/1.json
  def update
    respond_with Tagging.update(params[:id], params[:tag])
  end

  # DELETE /tags/1
  # DELETE /tags/1.json
  def destroy
    @tag = Tagging.find(params[:id])
    @tag.destroy

    respond_to do |format|
      format.json { no_content_as_json }
    end
  end
end
