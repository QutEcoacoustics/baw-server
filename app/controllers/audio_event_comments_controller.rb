class AudioEventCommentsController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource :audio_event
  load_and_authorize_resource :audio_event_comment, through: :audio_event, through_association: :comments
  respond_to :json

  # GET /audio_event_comments
  # GET /audio_event_comments.json
  def index
    #@audio_event_comments = AudioEventComment.accessible_by
    @audio_event_comments, constructed_options = Settings.api_response.response_index(
        params,
        current_user.accessible_comments,
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    respond_index
  end

  # GET /audio_event_comments/1
  # GET /audio_event_comments/1.json
  def show
    #@audio_event_comment = AudioEventComment.find(params[:id])
    respond_show
  end

  # GET /audio_event_comments/new
  # GET /audio_event_comments/new.json
  def new
    #@audio_event_comment = AudioEventComment.new
    @audio_event_comment.audio_event = @audio_event
    respond_show
  end

  # POST /audio_event_comments
  # POST /audio_event_comments.json
  def create
    #@audio_event_comment = AudioEventComment.new(params[:audio_event_comment])
    @audio_event_comment.audio_event = @audio_event

    if @audio_event_comment.save
      respond_create_success(audio_event_comment_url(@audio_event, @audio_event_comment))
    else
      respond_change_fail
    end

  end

  # PUT /audio_event_comments/1
  # PUT /audio_event_comments/1.json
  def update
    #@audio_event_comment = AudioEventComment.find(params[:id])
    if @audio_event_comment.update_attributes(params[:audio_event_comment])
      respond_show
    else
      respond_change_fail
    end

  end

  # DELETE /audio_event_comments/1
  # DELETE /audio_event_comments/1.json
  def destroy
    #@audio_event_comment = AudioEventComment.find(params[:id])
    @audio_event_comment.destroy
    respond_destroy
  end

  def filter
    filter_response = Settings.api_response.response_filter(
        params,
        current_user.accessible_comments,
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    render_api_response(filter_response)
  end

end
