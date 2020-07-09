class AudioEventCommentsController < ApplicationController
  include Api::ControllerHelper

  # GET /audio_events/:audio_event_id/comments
  def index
    do_authorize_class
    get_audio_event
    do_authorize_instance(:show, @audio_event)

    @audio_event_comments, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.audio_event_comments(current_user, Access::Core.levels, @audio_event),
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    respond_index(opts)
  end

  # GET /audio_events/:audio_event_id/comments/:id
  def show
    do_load_resource
    get_audio_event
    do_authorize_instance

    respond_show
  end

  # GET /audio_events/:audio_event_id/comments/new
  def new
    do_new_resource
    get_audio_event
    do_set_attributes
    do_authorize_instance

    respond_show
  end

  # POST /audio_events/:audio_event_id/comments
  def create
    do_new_resource
    do_set_attributes(audio_event_comment_params)
    get_audio_event
    do_authorize_instance

    if @audio_event_comment.save
      respond_create_success(audio_event_comment_path(@audio_event, @audio_event_comment))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /audio_events/:audio_event_id/comments/:id
  def update
    do_load_resource
    get_audio_event
    do_authorize_instance

    # allow any logged in user to flag an audio comment
    # only the user that created the audio comment (or admin) can update any other attribute
    is_creator = @audio_event_comment.creator.id == current_user.id
    is_admin = Access::Core.is_admin?(current_user)
    is_changing_only_flag =
        (audio_event_comment_update_params.include?(:audio_event_comment) &&
            ([:flag] - audio_event_comment_update_params[:audio_event_comment].symbolize_keys.keys).empty?)

    if is_creator || is_admin || is_changing_only_flag
      if @audio_event_comment.update(audio_event_comment_params)
        respond_show
      else
        respond_change_fail
      end
    else
      # otherwise, not allowed to update the comment
      fail CanCan::AccessDenied.new(I18n.t('devise.failure.unauthorized'), :update, AudioEventComment)
    end

  end

  # DELETE /audio_events/:audio_event_id/comments/:id
  def destroy
    do_load_resource
    get_audio_event
    do_authorize_instance

    @audio_event_comment.destroy
    add_archived_at_header(@audio_event_comment)
    respond_destroy
  end

  # GET|POST /audio_event_comments/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.audio_event_comments(current_user),
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def get_audio_event
    @audio_event = AudioEvent.find(params[:audio_event_id])

    # avoid the same project assigned more than once to a site
    if defined?(@audio_event_comment) && @audio_event_comment.audio_event.blank?
      @audio_event_comment.audio_event = @audio_event
    end
  end

  def audio_event_comment_params
    params.require(:audio_event_comment).permit(:audio_event_id, :comment, :flag, :flag_explain)
  end

  def audio_event_comment_update_params
    params.permit(:format, :audio_event_id, :id, {audio_event_comment: [:flag, :comment]})
  end

end
