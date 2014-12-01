class AudioEventCommentsController < ApplicationController
  include Api::ControllerHelper

# order matters for before_filter and load_and_authorize_resource!
  load_and_authorize_resource :audio_event

  # this is necessary so that the ability has access to permission.project
  before_filter :build_audio_event_comment, only: [:new, :create]

  load_and_authorize_resource :audio_event_comment, through: :audio_event, through_association: :comments
  respond_to :json

  # GET /audio_event_comments
  # GET /audio_event_comments.json
  def index
    #@audio_event_comments = AudioEventComment.accessible_by
    @audio_event_comments, constructed_options = Settings.api_response.response_index(
        params,
        current_user.is_admin? ? AudioEventComment.all : current_user.accessible_comments,
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    respond_index
  end

  # GET /audio_event_comments/1
  # GET /audio_event_comments/1.json
  def show
    respond_show
  end

  # GET /audio_event_comments/new
  # GET /audio_event_comments/new.json
  def new
    attributes_and_authorize
    respond_show
  end

  # POST /audio_event_comments
  # POST /audio_event_comments.json
  def create
    attributes_and_authorize

    if @audio_event_comment.save
      respond_create_success(audio_event_comment_url(@audio_event, @audio_event_comment))
    else
      respond_change_fail
    end

  end

  # PUT /audio_event_comments/1
  # PUT /audio_event_comments/1.json
  def update

    if @audio_event_comment.update_attributes(params[:audio_event_comment])
      respond_show
    else
      respond_change_fail
    end

  end

  # DELETE /audio_event_comments/1
  # DELETE /audio_event_comments/1.json
  def destroy
    @audio_event_comment.destroy
    respond_destroy
  end

  def filter
    filter_response = Settings.api_response.response_filter(
        params,
        current_user.is_admin? ? AudioEventComment.all : current_user.accessible_comments,
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    render_api_response(filter_response)
  end

  private

  def build_audio_event_comment
    @audio_event_comment = AudioEventComment.new
    @audio_event_comment.audio_event = @audio_event
  end

end
