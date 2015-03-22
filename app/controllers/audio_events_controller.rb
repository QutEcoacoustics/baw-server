require 'csv'

class AudioEventsController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource :audio_recording, except: [:show, :library, :library_paged, :download, :filter]
  load_and_authorize_resource :audio_event, through: :audio_recording, except: [:show, :library, :library_paged, :download, :filter]
  skip_authorization_check only: [:show, :library, :library_paged]

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
    filter_response = Settings.api_response.response_filter(
        api_filter_params,
        Access::Query.audio_events(current_user, Access::Core.levels_allow),
        AudioEvent,
        AudioEvent.filter_settings
    )
    render_api_response(filter_response)
  end

  def download

    download_params_cleaned = CleanParams.perform(audio_event_download_params)

    # first check what is available to authorise this request
    is_authorized = false
    if download_params_cleaned[:project_id]
      project = Project.where(id: (download_params_cleaned[:project_id])).first
      authorize! :show, project unless project.blank?
      is_authorized = true unless project.blank?
    else
      project = nil
    end

    if download_params_cleaned[:site_id]
      site = Site.where(id: (download_params_cleaned[:site_id])).first
      authorize! :show, site unless site.blank?
      is_authorized = true unless site.blank?
    else
      site = nil
    end

    if download_params_cleaned[:audio_recording_id] || download_params_cleaned[:recording_id] || download_params_cleaned[:audiorecording_id]
      audio_recording = AudioRecording.where(
          id:
              (download_params_cleaned[:audio_recording_id] ||
                  download_params_cleaned[:recording_id] ||
                  download_params_cleaned[:audiorecording_id]).to_i).first
      authorize! :show, audio_recording unless audio_recording.blank?
      is_authorized = true unless audio_recording.blank?
    else
      audio_recording = nil
    end

    if download_params_cleaned[:start_offset]
      start_offset = download_params_cleaned[:start_offset]
    else
      start_offset = nil
    end

    if download_params_cleaned[:end_offset]
      end_offset = download_params_cleaned[:end_offset]
    else
      end_offset = nil
    end

    unless is_authorized
      fail CustomErrors::RoutingArgumentError, 'must provide existing audio_recording_id, start_offset, and end_offset or project_id or site_id'
    end

    # set file name
    time_now = Time.zone.now
    file_name_append = "#{time_now.strftime('%Y%m%d')}-#{time_now.strftime('%H%M%S')}"
    file_name = 'annotations'

    unless project.blank?
      file_name = NameyWamey.create_project_name(project, '', '')
    end

    unless site.blank?
      file_name = NameyWamey.create_site_name(site.projects.first, site, '', '')
    end

    unless audio_recording.blank? && start_offset.blank? && end_offset.blank?
      file_name = NameyWamey.create_audio_recording_name(audio_recording, start_offset, end_offset, '', '')
    end

    @formatted_annotations = download_format AudioEvent.csv_filter(current_user, download_params_cleaned).limit(1000)

    respond_to do |format|
      format.csv { render_csv("#{file_name.trim('.', '')}-#{file_name_append}") }
      format.json { render json: @formatted_annotations }
    end
  end

  private

  # @param [Array<AudioEvent>] audio_events
  def download_format(audio_events)

    list = []

    audio_events.each do |audio_event|

      abs_start = audio_event.audio_recording.recorded_date.advance(seconds: audio_event[:start_time_seconds])
      abs_end = audio_event.audio_recording.recorded_date.advance(seconds: audio_event[:end_time_seconds])

      audio_event_duration_duration = audio_event.end_time_seconds - audio_event.start_time_seconds
      aligned_30_sec_start = (audio_event.start_time_seconds / 30.0).floor * 30.0
      aligned_30_sec_end = [aligned_30_sec_start + 30.0, audio_event.audio_recording.duration_seconds].min

# Annotation Id, Audio Recording Id, Start Date, Start Time, End Date, End Time, Timezone, Max Frequency (hz),
# Min Frequency (hz), Project Ids, Project Names, Site Id, Site Name, Created By Id, Created By Name, Listen Url, Library Url,
# Tag 1 Id, Tag 1 Text, Tag 1 Type, Tag 1 Is Taxanomic, Tag 2 Id, Tag 2 Text, Tag 2 Type, Tag 2 Is Taxanomic,
# Tag 3 Id, Tag 3 Text, Tag 3 Type, Tag 3 Is Taxanomic

      audio_event_items = [
          audio_event.id,
          audio_event.audio_recording_id,
          abs_start.strftime('%Y/%m/%d'),
          abs_start.strftime('%H:%M:%S'),
          abs_end.strftime('%Y/%m/%d'),
          abs_end.strftime('%H:%M:%S'),
          audio_event_duration_duration,
          abs_end.strftime('%z'),
          audio_event.high_frequency_hertz,
          audio_event.low_frequency_hertz,
          audio_event.audio_recording.site.projects.collect { |project| project.id }.join(' | '),
          audio_event.audio_recording.site.projects.collect { |project| project.name }.join(' | '),
          audio_event.audio_recording.site.id,
          audio_event.audio_recording.site.name,
          audio_event.creator_id,
          audio_event.creator.user_name,
          "http://#{Settings.host.name}/listen/#{audio_event.audio_recording_id}?start=#{aligned_30_sec_start.to_i}&end=#{aligned_30_sec_end.to_i}",
          "http://#{Settings.host.name}/library/#{audio_event.audio_recording_id}/audio_events/#{audio_event.id}"
      ]

      audio_event.tags.order('tags.id ASC').each do |tag|
        audio_event_items.push tag.id, tag.text, tag.type_of_tag, tag.is_taxanomic
      end

      list.push audio_event_items
    end

    list
  end

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
