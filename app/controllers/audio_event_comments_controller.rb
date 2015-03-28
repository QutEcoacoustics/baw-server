class AudioEventCommentsController < ApplicationController
  include Api::ControllerHelper

  # order matters for before_action and load_and_authorize_resource!
  load_and_authorize_resource :audio_event, except: [:filter]

  # this is necessary so that the ability has access to permission.project
  before_action :build_audio_event_comment, only: [:new, :create]

  load_and_authorize_resource :audio_event_comment, through: :audio_event, through_association: :comments, except: [:filter]

# GET /audio_event_comments
# GET /audio_event_comments.json
  def index
    #@audio_event_comments = AudioEventComment.accessible_by
    @audio_event_comments, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_audio_event_comments,
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    respond_index(opts)
  end

# GET /audio_event_comments/1
# GET /audio_event_comments/1.json
  def show
    respond_show
  end

# GET /audio_event_comments/new
# GET /audio_event_comments/new.json
  def new
    do_authorize!

    respond_show
  end

# POST /audio_event_comments
# POST /audio_event_comments.json
  def create
    attributes_and_authorize(audio_event_comment_params)

    if @audio_event_comment.save
      respond_create_success(audio_event_comment_url(@audio_event, @audio_event_comment))
    else
      respond_change_fail
    end

  end

# PUT /audio_event_comments/1
# PUT /audio_event_comments/1.json
  def update
    # allow any logged in user to flag an audio comment
    # only the user that created the audio comment (or admin) can update any other attribute
    is_creator = @audio_event_comment.creator.id == current_user.id
    is_admin = Access::Check.is_admin?(current_user)
    is_changing_only_flag =
        (audio_event_comment_update_params.include?(:audio_event_comment) &&
        ([:flag] - audio_event_comment_update_params[:audio_event_comment].symbolize_keys.keys).empty?)

    if is_creator || is_admin || is_changing_only_flag
      if @audio_event_comment.update_attributes(audio_event_comment_params)
        respond_show
      else
        respond_change_fail
      end
    else
      # otherwise, not allowed to update the comment
      fail CanCan::AccessDenied.new(I18n.t('devise.failure.unauthorized'), :update, AudioEventComment)
    end

  end

# DELETE /audio_event_comments/1
# DELETE /audio_event_comments/1.json
  def destroy
    @audio_event_comment.destroy
    add_archived_at_header(@audio_event_comment)
    respond_destroy
  end

  def filter
    authorize! :filter, AudioEventComment
    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_audio_event_comments,
        AudioEventComment,
        AudioEventComment.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def build_audio_event_comment
    @audio_event_comment = AudioEventComment.new
    @audio_event_comment.audio_event = @audio_event
  end

  def audio_event_comment_params
    params.require(:audio_event_comment).permit(:audio_event_id, :comment, :flag, :flag_explain)
  end

  def audio_event_comment_update_params
    params.permit(:format, :audio_event_id, :id, {audio_event_comment: [:flag, :comment]})
  end

  def get_audio_event_comments
    Access::Query.audio_event_comments(current_user, Access::Core.levels_allow)
  end

end
