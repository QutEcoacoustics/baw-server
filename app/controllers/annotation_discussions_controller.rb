class AnnotationDiscussionsController < ApplicationController
  add_breadcrumb 'Home', :root_path

  load_and_authorize_resource :audio_event, :annotation_discussion

  # actions are all api-only
  # a user or audio_event can :include annotation_discussions in the response for a single item

  def index
    # list of annotation_discussions (probably reverse chronological order and paged)
    AnnotationDiscussion.filtered(params)
  end

  def show
    # a single existing annotation_discussion for a single user or a single audio_event

  end

  def new
    # required attributes for new annotation_discussion
    @annotation_discussion = AnnotationDiscussion.new
    render json: @annotation_discussion.to_json(only: [:audio_event_id, :comment])
  end

  def create
    # create a new annotation_discussion
    @annotation_discussion = AnnotationDiscussion.new(params[:annotation_discussion])
    @annotation_discussion.audio_event << @audio_event
  end

  def update
    # update an existing annotation_discussion
    @annotation_discussion = AnnotationDiscussion.where(id: params[:id])
    @annotation_discussion.audio_event << @audio_event
  end

  def destroy
    # delete (using paranoid/soft delete) an existing annotation_discussion
  end

end
