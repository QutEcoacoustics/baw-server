require 'csv'

class AudioEventsController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource :audio_recording, except: [:show, :download, :filter]
  load_and_authorize_resource :audio_event, through: :audio_recording, except: [:show, :download, :filter]
  skip_authorization_check only: [:show]

  # GET /audio_events
  # GET /audio_events.json
  def index
    if @audio_recording
      events = @audio_recording.audio_events
      events = events.end_after(audio_event_index_params[:start_offset]) if audio_event_index_params[:start_offset]
      events = events.start_before(audio_event_index_params[:end_offset]) if audio_event_index_params[:end_offset]
      render json: events.to_json(include: {taggings: {include: :tag}})
    else
      render json: {error: 'An audio recording must be specified.'}, status: :bad_request
    end
  end

  # GET /audio_events/1
  # GET /audio_events/1.json
  def show
    #render json: json_format(AudioEvent.where(id:params[:id]).first)
    #render json: AudioEvent.find(params[:id]).to_json(include: {taggings: {include: :tag}})
    # options = {
    #     new: [json_format(AudioEvent.where(id: params[:id]).first)],
    #     old: AudioEvent.where(id: params[:id]).includes(taggings: :tag)
    # }

    # allow logged-in users to access reference audio events
    # they would otherwise not have access to

    request_params = audio_event_show_params.dup.symbolize_keys
    request_params[:audio_event_id] = request_params[:id]

    audio_recording = auth_custom_audio_recording(request_params)
    audio_event = auth_custom_audio_event(request_params, audio_recording)

    render json: json_format(audio_event)
  end

  # GET /audio_events/new
  # GET /audio_events/new.json
  def new
    render json: @audio_event.to_json(only: [:start_time_seconds, :end_time_seconds, :low_frequency_hertz, :high_frequency_hertz, :is_reference])
  end

  # POST /audio_events
  # POST /audio_events.json
  def create
    @audio_event.audio_recording = @audio_recording

    if @audio_event.save
      render json: @audio_event.to_json(include: {taggings: {include: :tag}}), status: :created
    else
      render json: @audio_event.errors, status: :unprocessable_entity
    end
  end

  # PUT /audio_events/1
  # PUT /audio_events/1.json
  def update
    if @audio_event.update(audio_event_params)
      render json: @audio_event.to_json(include: :taggings), status: :created
    else
      render json: @audio_event.errors, status: :unprocessable_entity
    end
  end

  # DELETE /audio_events/1
  # DELETE /audio_events/1.json
  def destroy
    @audio_event.destroy
    add_archived_at_header(@audio_event)
    head :no_content
  end

  def filter
    authorize! :filter, AudioEvent
    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::Query.audio_events(current_user, Access::Core.levels_allow),
        AudioEvent,
        AudioEvent.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def download

    params_cleaned = CleanParams.perform(audio_event_download_params)

    is_authorized = false

    project = nil
    site = nil
    audio_recording = nil
    start_offset = nil
    end_offset = nil

    # check which params are available to authorise this request

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

    unless is_authorized
      fail CustomErrors::RoutingArgumentError, 'must provide existing audio_recording_id, start_offset, and end_offset or project_id or site_id'
    end

    # create file name
    time_now = Time.zone.now
    file_name_append = "#{time_now.strftime('%Y%m%d-%H%M%S')}"
    file_name = 'annotations'

    unless project.blank?
      file_name = NameyWamey.create_project_name(project, '', '')
    end

    unless site.blank?
      file_name = NameyWamey.create_site_name(site.projects.first, site, '', '')
    end

    unless audio_recording.blank?
      file_name = NameyWamey.create_audio_recording_name(audio_recording, start_offset, end_offset, '', '')
    end

    # create query

    query = AudioEvent.csv_query(project, site, audio_recording, start_offset, end_offset)
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
        :project_id, :projectId,
        :site_id, :siteId,
        :start_offset, :startOffset,
        :end_offset, :endOffset,
        :format)
  end

  def audio_event_show_params
    params.permit(:id, :project_id, :site_id, :format, :audio_recording_id, audio_event: {})
  end

end
