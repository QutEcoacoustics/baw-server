class AudioEventCommentsController < ApplicationController
  add_breadcrumb 'Home', :root_path

  load_and_authorize_resource :audio_event, :audio_event_comment

  # actions are all api-only
  # a user or audio_event can include annotation_discussions in the response for a single item

  def index
    # list of annotation_discussions (probably reverse chronological order and paged)
    @audio_event_comments = AudioEventComment.filtered(@audio_event, params)
    render json: @audio_event_comments.to_json
  end

  def show
    # a single existing annotation_discussion for a single user or a single audio_event

  end

  def new
    # required attributes for new annotation_discussion
    @audio_event_comment = AudioEventComment.new
    render json: @audio_event_comment.to_json(only: [:audio_event_id, :comment])
  end

  def create
    # create a new annotation_discussion
    @audio_event_comment = AudioEventComment.new(params[:audio_event_comment])
    @audio_event_comment.audio_event << @audio_event
  end

  def update
    # update an existing annotation_discussion
    @audio_event_comment = AudioEventComment.where(id: params[:id])
    @audio_event_comment.audio_event << @audio_event
  end

  def destroy
    # delete (using paranoid/soft delete) an existing annotation_discussion
  end

end
