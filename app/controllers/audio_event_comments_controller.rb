class AudioEventCommentsController < ApplicationController

  load_and_authorize_resource :audio_event
  load_and_authorize_resource :audio_event_comment, through: :audio_event, through_association: :comments
  respond_to :json

  # GET /audio_event_comments
  # GET /audio_event_comments.json
  def index
    #@audio_event_comments = AudioEventComment.accessible_by
    render json: @audio_event_comments
  end

  # GET /audio_event_comments/1
  # GET /audio_event_comments/1.json
  def show
    #@audio_event_comment = AudioEventComment.find(params[:id])
    render json: @audio_event_comment
  end

  # GET /audio_event_comments/new
  # GET /audio_event_comments/new.json
  def new
    #@audio_event_comment = AudioEventComment.new
    @audio_event_comment.audio_event = @audio_event
    render json: @audio_event_comment
  end

  # POST /audio_event_comments
  # POST /audio_event_comments.json
  def create
    #@audio_event_comment = AudioEventComment.new(params[:audio_event_comment])
    @audio_event_comment.audio_event = @audio_event

    if @audio_event_comment.save
      render json: @audio_event_comment, status: :created, location: audio_event_comment_url(@audio_event, @audio_event_comment)
    else
      render json: @audio_event_comment.errors, status: :unprocessable_entity
    end
  end

  # PUT /audio_event_comments/1
  # PUT /audio_event_comments/1.json
  def update
    #@audio_event_comment = AudioEventComment.find(params[:id])

    if @audio_event_comment.update_attributes(params[:audio_event_comment])
      head :no_content
    else
      render json: @audio_event_comment.errors, status: :unprocessable_entity
    end

  end

  # DELETE /audio_event_comments/1
  # DELETE /audio_event_comments/1.json
  def destroy
    #@audio_event_comment = AudioEventComment.find(params[:id])
    @audio_event_comment.destroy

    head :no_content
  end
end
