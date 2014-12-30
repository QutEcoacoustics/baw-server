class TaggingsController < ApplicationController

  load_and_authorize_resource :audio_recording, except: [:user_index]
  load_and_authorize_resource :audio_event, except: [:user_index]
  load_resource :tagging, except: [:user_index]
  load_and_authorize_resource :user, only: [:user_index]
  respond_to :json

  # /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/

  # GET /taggings
  # GET /taggings.json
  # GET /taggings/user/1/tags.json
  def index
    if @audio_event
      render json: @audio_event.taggings.to_json(include: [:tag])
    else
      render json: Tagging.all.to_json(include: [:tag])
    end
  end

  # GET /taggings/user/:user_id/tags
  def user_index
    if params[:user_id]
      render json: Tagging
      .includes(:tag, :audio_event)
      .where('(audio_events_tags.updater_id = ? OR audio_events_tags.creator_id = ?)', params[:user_id], params[:user_id])
      .order('updated_at DESC, created_at DESC')
      .limit(10)
      .to_json(include: [:tag, :audio_event])
    else
      raise ActiveRecord::RecordNotFound, 'Could not get taggings.'
    end
  end

  # GET /taggings/1
  # GET /taggings/1.json
  def show
    respond_with @tagging
  end

  # GET /taggings/new
  # GET /taggings/new.json
  def new
    respond_with @tagging
  end

  # POST /taggings
  # POST /taggings.json
  def create
    # @audio_recording, @audio_event and @tagging are initialised/preloaded by load_resource/load_and_authorize_resource
    if tagging_params && tagging_params[:tag_attributes] && tagging_params[:tag_attributes][:text]
      @tag = Tag.where(text: tagging_params[:tag_attributes][:text]).first
      if @tag.blank?
        # if the tag with the name does not already exist, create it via tag_attributes
        @tag = Tag.new(tagging_params[:tag_attributes])
        unless @tag.save
          render json: @tag.errors, status: :unprocessable_entity and return
        end
      end
      @tagging.tag = @tag
    else
      # tag attributes are directly available
      @tagging = Tagging.new(tagging_params)
    end

    @tagging.audio_event = @audio_event

    if @tagging.save
      render json: @tagging, status: :created
    else
      render json: @tagging.errors, status: :unprocessable_entity
    end
  end

  # PUT /taggings/1
  # PUT /taggings/1.json
  def update
    respond_with Tagging.update(params[:id], params[:tag])
  end

  # DELETE /taggings/1
  # DELETE /taggings/1.json
  def destroy
    @tagging.destroy
    @tag.destroy

    respond_to do |format|
      format.json { no_content_as_json }
    end
  end

  private

  def tagging_params
    params.require(:tagging).permit(:audio_event_id, :tag_id, tag_attributes: [:is_taxanomic, :text, :type_of_tag, :retired, :notes])
  end
end
