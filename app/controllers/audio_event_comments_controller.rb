class AudioEventCommentsController < ApplicationController
  add_breadcrumb 'Home', :root_path

  load_and_authorize_resource

  # actions are all api-only
  # a user or audio_event can include annotation_discussions in the response for a single item

  def index
    # list of annotation_discussions (probably reverse chronological order and paged)
    #@audio_event_comments = AudioEventComment.filtered(current_user, @audio_event, params)
    render json: @audio_event_comments.to_json(include: {creator: {only: :user_name}, updater: {only: :user_name}})
    #.image.url(:span1)
  end

  #def show
    # a single existing annotation_discussion for a single user or a single audio_event

  #end

  # def new
  #   # required attributes for new annotation_discussion
  #   @audio_event_comment = AudioEventComment.new
  #   render json: @audio_event_comment.to_json(only: [:audio_event_id, :comment])
  # end

  def create
    # create a new annotation_discussion
    #@audio_event_comment = AudioEventComment.new(params[:audio_event_comment])
    @audio_event_comment.audio_event = @audio_event

    if @audio_event_comment.save
      render json: @audio_event_comment.to_json(include: :audio_event), status: :created
    else
      render json: @audio_event_comment.errors, status: :unprocessable_entity
    end
  end

  def update
    # update an existing annotation_discussion
    #@audio_event_comment = AudioEventComment.where(id: params[:id]).first
    #raise ActiveRecord::RecordNotFound, "Could not find comment with id #{params[:id]}" if @audio_event_comment.blank?

    @audio_event_comment.comment = params[:comment] if params.include?(:comment)
    @audio_event_comment.flag = params[:flag] if params.include?(:flag)

    if @audio_event_comment.save
      head :no_content
    else
      render json: @audio_event_comment.errors, status: :unprocessable_entity
    end
  end

  def destroy
    # delete (using paranoid/soft delete) an existing audio_event_comment
    #@audio_event_comment = AudioEventComment.where(id: params[:id]).first

    #raise ActiveRecord::RecordNotFound, "Could not find comment with id #{params[:id]}" if @audio_event_comment.blank?

    add_archived_at_header(@audio_event_comment)
    @audio_event_comment.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

end
