require 'csv'

class AudioEventsController < ApplicationController
  include Api::ControllerHelper

  skip_authorization_check only: [:show]

  # GET /audio_recordings/:audio_recording_id/audio_events
  def index
    do_authorize_class
    get_audio_recording

    @audio_events, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::Query.audio_recording_audio_events(@audio_recording, current_user),
        AudioEvent,
        AudioEvent.filter_settings
    )
    respond_index(opts)
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/:id
  def show
    # allow logged-in users to access reference audio events
    # they would otherwise not have access to

    request_params = audio_event_show_params.dup.symbolize_keys
    request_params[:audio_event_id] = request_params[:id]

    @audio_recording = auth_custom_audio_recording(request_params)
    @audio_event = auth_custom_audio_event(request_params, @audio_recording)

    respond_show
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/new
  def new
    do_new_resource
    get_audio_recording
    do_set_attributes
    do_authorize_instance

    respond_show
  end

  # POST /audio_recordings/:audio_recording_id/audio_events
  def create
    do_new_resource
    do_set_attributes(audio_event_params)
    get_audio_recording
    do_authorize_instance

    if @audio_event.save
      respond_create_success(audio_recording_audio_event_path(@audio_recording, @audio_event))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /audio_recordings/:audio_recording_id/audio_events/:id
  def update
    do_load_resource
    get_audio_recording
    do_authorize_instance

    if @audio_event.update(audio_event_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /audio_recordings/:audio_recording_id/audio_events/:id
  def destroy
    do_load_resource
    get_audio_recording
    do_authorize_instance

    @audio_event.destroy
    add_archived_at_header(@audio_event)

    respond_destroy
  end

  # GET|POST /audio_events/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::Query.audio_events(current_user),
        AudioEvent,
        AudioEvent.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/download
  # GET /projects/:project_id/audio_events/download
  # GET /projects/:project_id/sites/:site_id/audio_events/download
  def download

    params_cleaned = CleanParams.perform(audio_event_download_params)

    is_authorized = false

    user = nil
    project = nil
    site = nil
    audio_recording = nil
    start_offset = nil
    end_offset = nil

    # check which params are available to authorise this request

    # user id
    if params_cleaned[:user_id]
      user = User.where(id: params_cleaned[:user_id].to_i).first
      unless user.blank?
        authorize! :audio_events, user
        is_authorized = true
      end
    end

    # project id
    if params_cleaned[:project_id]
      project = Project.where(id: params_cleaned[:project_id].to_i).first
      unless project.blank?
        authorize! :show, project
        is_authorized = true
      end
    end

    # site id
    if params_cleaned[:site_id]
      site = Site.where(id: params_cleaned[:site_id].to_i).first
      unless site.blank?
        authorize! :show, site
        is_authorized = true
      end
    end

    # audio recording id
    audio_recording_id = params_cleaned[:audio_recording_id] || params_cleaned[:recording_id] || params_cleaned[:audiorecording_id] || nil
    if audio_recording_id
      audio_recording = AudioRecording.where(id: audio_recording_id.to_i).first
      unless audio_recording.blank?
        authorize! :show, audio_recording
        is_authorized = true
      end
    end

    # start offset
    if params_cleaned[:start_offset]
      start_offset = params_cleaned[:start_offset].to_f
    else
      start_offset = 0
    end

    # end offset
    if params_cleaned[:end_offset]
      end_offset = params_cleaned[:end_offset].to_f
    else
      end_offset = audio_recording.duration_seconds if audio_recording
    end

    # timezone
    if params_cleaned[:selected_timezone_name]
      timezone_name = params_cleaned[:selected_timezone_name]
    else
      timezone_name = 'UTC'
    end

    unless is_authorized
      fail CustomErrors::RoutingArgumentError, 'must provide existing audio_recording_id, start_offset, and end_offset or project_id or site_id or user_id'
    end

    # create file name
    time_now = Time.zone.now
    file_name_append = "#{time_now.strftime('%Y%m%d-%H%M%S')}"
    file_name = 'annotations'

    unless user.blank?
      file_name = NameyWamey.create_user_name(user)
    end

    unless project.blank?
      file_name = NameyWamey.create_project_name(project)
    end

    unless site.blank?
      file_name = NameyWamey.create_site_name(site.projects.first, site)
    end

    unless audio_recording.blank?
      file_name = NameyWamey.create_audio_recording_name(audio_recording, start_offset, end_offset)
    end

    # create query

    query = AudioEvent.csv_query(user, project, site, audio_recording, start_offset, end_offset, timezone_name)
    query_sql = query.to_sql
    @formatted_annotations = AudioEvent.connection.select_all(query_sql)

    respond_to do |format|
      format.csv { render_csv("#{file_name.trim('.', '')}-#{file_name_append}") }
      format.json { render json: @formatted_annotations }
    end
  end

  private

  # @param [AudioEvent] audio_event
  def json_format(audio_event)

    user = audio_event.creator
    user_name = user.blank? ? '' : user.user_name
    user_id = user.blank? ? '' : user.id

    audio_event_hash = {
        audio_event_id: audio_event.id,
        id: audio_event.id,
        audio_event_start_date: audio_event.audio_recording.recorded_date.advance(seconds: audio_event.start_time_seconds),
        audio_recording_id: audio_event.audio_recording_id,
        audio_recording_duration_seconds: audio_event.audio_recording.duration_seconds,
        audio_recording_recorded_date: audio_event.audio_recording.recorded_date,
        site_name: audio_event.audio_recording.site.name,
        site_id: audio_event.audio_recording.site.id,
        owner_name: user_name,
        owner_id: user_id,
        is_reference: audio_event.is_reference,
        start_time_seconds: audio_event.start_time_seconds,
        end_time_seconds: audio_event.end_time_seconds,
        high_frequency_hertz: audio_event.high_frequency_hertz,
        low_frequency_hertz: audio_event.low_frequency_hertz,
        updated_at: audio_event.updated_at,
        updater_id: audio_event.updater_id,
        created_at: audio_event.created_at,
        creator_id: audio_event.creator_id,
    }

    audio_event_hash[:tags] = audio_event.tags.map do |tag|
      {
          id: tag.id,
          text: tag.text,
          is_taxanomic: tag.is_taxanomic,
          retired: tag.retired,
          type_of_tag: tag.type_of_tag
      }
    end

    audio_event_hash[:projects] = audio_event.audio_recording.site.projects.map do |project|
      {
          id: project.id,
          name: project.name
      }
    end

    # next and prev are just in order of ids (essentially the order the audio events were created)
    next_event = AudioEvent.where('id > ?', audio_event.id).order('id ASC').first
    prev_event = AudioEvent.where('id < ?', audio_event.id).order('id DESC').first
    audio_event_hash[:paging] = {next_event: {}, prev_event: {}}

    audio_event_hash[:paging][:next_event][:audio_event_id] = next_event.id unless next_event.blank?
    audio_event_hash[:paging][:next_event][:audio_recording_id] = next_event.audio_recording_id unless next_event.blank?
    audio_event_hash[:paging][:prev_event][:audio_event_id] = prev_event.id unless prev_event.blank?
    audio_event_hash[:paging][:prev_event][:audio_recording_id] = prev_event.audio_recording_id unless prev_event.blank?

    audio_event_hash
  end

  def audio_event_params
    params.require(:audio_event).permit(
        :audio_recording_id,
        :start_time_seconds, :end_time_seconds,
        :low_frequency_hertz, :high_frequency_hertz,
        :is_reference,
        tags_attributes: [:is_taxanomic, :text, :type_of_tag, :retired, :notes],
        tag_ids: [])
  end

  def audio_event_index_params
    params.permit(
        :start_offset, :end_offset,
        :format, :audio_recording_id, audio_event: {})
  end

  def audio_event_download_params
    params.permit(
        :audio_recording_id, :audioRecordingId, :audiorecording_id, :audiorecordingId, :recording_id, :recordingId,
        :user_id, :userId,
        :project_id, :projectId,
        :site_id, :siteId,
        :start_offset, :startOffset,
        :end_offset, :endOffset,
        :selected_timezone_name, :selectedTimezoneName,
        :format)
  end

  def audio_event_show_params
    params.permit(:id, :project_id, :site_id, :format, :audio_recording_id, audio_event: {})
  end

  def get_audio_recording
    @audio_recording = AudioRecording.find(params[:audio_recording_id])

    # avoid the same project assigned more than once to a site
    if defined?(@audio_event) && @audio_event.audio_recording.blank?
      @audio_event.audio_recording = @audio_recording
    end
  end

end
