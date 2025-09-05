# frozen_string_literal: true

class AudioEventsController < ApplicationController
  include Api::ControllerHelper

  skip_authorization_check only: [:show]

  def should_skip_bullet?
    # Bullet raises a  false positive here... our custom fields load an attribute from the database, but if attribute
    # has the same name as the association, bullet gets confused and thinks we should have eager loaded the association
    # TODO: fix, it's probably bad practice to load custom fields that can clash with active record attributes
    action_sym == :filter
  end

  # GET /audio_recordings/:audio_recording_id/audio_events
  def index
    do_authorize_class
    get_audio_recording

    @audio_events, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_events(current_user, audio_recording: @audio_recording),
      AudioEvent,
      AudioEvent.filter_settings
    )
    respond_index(opts)
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/:id
  def show
    # allow logged-in users to access reference audio events
    # they would otherwise not have access to

    request_params = audio_event_show_params.to_h
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

    respond_new
  end

  # POST /audio_recordings/:audio_recording_id/audio_events
  def create
    do_new_resource
    do_set_attributes(audio_event_params)

    get_audio_recording
    do_authorize_instance

    if @audio_event.save!
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
  # Handled in Archivable
  # Using callback defined in Archivable
  before_destroy do
    get_audio_recording
  end

  # GET|POST /audio_events/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_events(current_user),
      AudioEvent,
      AudioEvent.filter_settings
    )

    respond_filter(filter_response, opts)
  end

  # GET /audio_recordings/:audio_recording_id/audio_events/download
  # GET /projects/:project_id/audio_events/download
  # GET /projects/:project_id/regions/:region_id/audio_events/download
  # GET /projects/:project_id/sites/:site_id/audio_events/download
  def download
    params_cleaned = CleanParams.perform(audio_event_download_params)

    is_authorized = false

    user = nil
    project = nil
    site = nil
    audio_recording = nil
    end_offset = nil

    # check which params are available to authorize this request

    # user id
    if params_cleaned[:user_id]
      user = User.where(id: params_cleaned[:user_id].to_i).first
      if user.present?
        authorize! :audio_events, user
        is_authorized = true
      end
    end

    # project id
    if params_cleaned[:project_id]
      project = Project.where(id: params_cleaned[:project_id].to_i).first
      if project.present?
        authorize! :show, project
        is_authorized = true
      end
    end

    # region id
    if params_cleaned[:region_id]
      region = Region.where(id: params_cleaned[:region_id].to_i).first
      if region.present?
        authorize! :show, region
        is_authorized = true
      end
    end

    # site id
    if params_cleaned[:site_id]
      site = Site.where(id: params_cleaned[:site_id].to_i).first
      if site.present?
        authorize! :show, site
        is_authorized = true
      end
    end

    # audio recording id
    audio_recording_id = params_cleaned[:audio_recording_id] || params_cleaned[:recording_id] || params_cleaned[:audiorecording_id] || nil
    if audio_recording_id
      audio_recording = AudioRecording.where(id: audio_recording_id.to_i).first
      if audio_recording.present?
        authorize! :show, audio_recording
        is_authorized = true
      end
    end

    # start offset
    start_offset = if params_cleaned[:start_offset]
                     params_cleaned[:start_offset].to_f
                   else
                     0
                   end

    # end offset
    if params_cleaned[:end_offset]
      end_offset = params_cleaned[:end_offset].to_f
    elsif audio_recording
      end_offset = audio_recording.duration_seconds
    end

    # timezone
    timezone_name = params_cleaned[:selected_timezone_name] || 'UTC'

    unless is_authorized
      raise CustomErrors::RoutingArgumentError,
        'must provide existing audio_recording_id, start_offset, and end_offset or project_id or or region_id or site_id or user_id'
    end

    # create file name
    time_now = Time.zone.now
    file_name_append = time_now.strftime('%Y%m%d-%H%M%S').to_s
    file_name = 'annotations'

    file_name = NameyWamey.create_user_name(user) if user.present?

    file_name = NameyWamey.create_project_name(project) if project.present?

    file_name = NameyWamey.create_site_name(site.projects.first, site) if site.present?

    if audio_recording.present?
      file_name = NameyWamey.create_audio_recording_name(audio_recording, start_offset, end_offset)
    end

    # create query

    query = AudioEvent.csv_query(user, project, region, site, audio_recording, start_offset, end_offset, timezone_name)
    query_sql = query.to_sql
    @formatted_annotations = AudioEvent.connection.select_all(query_sql)

    respond_to do |format|
      format.csv { render_csv("#{file_name.trim('.', '')}-#{file_name_append}") }
      format.json { render json: @formatted_annotations }
    end
  end

  private

  def audio_event_params
    params.require(:audio_event).permit(
      :audio_recording_id,
      :start_time_seconds, :end_time_seconds,
      :low_frequency_hertz, :high_frequency_hertz,
      :is_reference,
      :channel,
      # AT 2021: disabled. Nested associations are extremely complex,
      # and as far as we are aware, they are not used anywhere in production
      # TODO: remove on passing test suite
      #tags_attributes: [:is_taxonomic, :text, :type_of_tag, :retired, :notes],
      tag_ids: []
    )
  end

  def audio_event_index_params
    params.permit(
      :start_offset, :end_offset,
      :format, :audio_recording_id, audio_event: {}
    )
  end

  def audio_event_download_params
    params.permit(
      :audio_recording_id, :audioRecordingId, :audiorecording_id, :audiorecordingId, :recording_id, :recordingId,
      :user_id, :userId,
      :project_id, :projectId,
      :site_id, :siteId,
      :region_id, :regionId,
      :start_offset, :startOffset,
      :end_offset, :endOffset,
      :selected_timezone_name, :selectedTimezoneName,
      :format
    )
  end

  def audio_event_show_params
    params.permit(:id, :project_id, :site_id, :format, :audio_recording_id, audio_event: {})
  end

  def get_audio_recording
    @audio_recording = AudioRecording.find(params[:audio_recording_id])

    # avoid the same project assigned more than once to a site
    @audio_event.audio_recording = @audio_recording if defined?(@audio_event) && @audio_event.audio_recording.blank?
  end
end
