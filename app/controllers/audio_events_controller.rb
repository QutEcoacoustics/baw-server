require 'csv'

class AudioEventsController < ApplicationController

  load_and_authorize_resource :audio_recording, except: [:new, :library, :library_paged]
  load_and_authorize_resource :audio_event, through: :audio_recording, except: [:new, :library, :library_paged, :download]
  skip_authorization_check only: [:library, :library_paged, :download]
  respond_to :json

  # GET /audio_events
  # GET /audio_events.json
  def index
    if @audio_recording
      events = @audio_recording.audio_events
      events = events.end_after(params[:start_offset]) if params[:start_offset]
      events = events.start_before(params[:end_offset]) if params[:end_offset]
      render json: events.to_json(include: {taggings: {include: :tag}})
    else
      render json: {error: 'An audio recording must be specified.'}, status: :bad_request
    end
  end

  def library
    authorize! :library, AudioEvent
    response_hash = library_format(current_user, params)
    render json: response_hash
  end

  def library_paged
    authorize! :library, AudioEvent
    response_hash = library_format(current_user, params)

    total_query = AudioEvent.filtered(current_user, params).offset(nil).limit(nil)
    total = total_query.count

    paged_info = {
        page: params[:page],
        items: params[:items],
        total: total,
        entries: response_hash
    }

    render json: paged_info

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

    render json: json_format(AudioEvent.where(id: params[:id]).first)
  end

  # GET /audio_events/new
  # GET /audio_events/new.json
  def new
    @audio_event = AudioEvent.new

    render json: @audio_event.to_json(only: [:start_time_seconds, :end_time_seconds, :low_frequency_hertz, :high_frequency_hertz, :is_reference])
  end

  # POST /audio_events
  # POST /audio_events.json
  def create
    @audio_event = AudioEvent.new(params[:audio_event])
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
    @audio_event.attributes = params[:audio_event]
    if @audio_event.save
      render json: @audio_event.to_json(include: :taggings), status: :created
    else
      render json: @audio_event.errors, status: :unprocessable_entity
    end
  end

  # DELETE /audio_events/1
  # DELETE /audio_events/1.json
  def destroy
    @audio_event = AudioEvent.find(params[:id])
    add_archived_at_header(@audio_event)
    respond_with @audio_event.destroy
  end


  def download
    @formatted_annotations = download_format AudioEvent.csv_filter(current_user, params).limit(1000)
    respond_to do |format|
      format.csv {
        time_now = Time.zone.now
        render_csv("annotations-#{time_now.strftime('%Y%m%d')}-#{time_now.strftime('%H%M%S')}")
      }
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
          'UTC',
          audio_event.high_frequency_hertz,
          audio_event.low_frequency_hertz,
          audio_event.audio_recording.site.projects.collect { |project| project.id }.join(' | '),
          audio_event.audio_recording.site.projects.collect { |project| project.name }.join(' | '),
          audio_event.audio_recording.site.id,
          audio_event.audio_recording.site.name,
          audio_event.creator_id,
          audio_event.creator.user_name,
          "http://baw.ecosounds.org/listen/#{audio_event.audio_recording_id}?start=#{aligned_30_sec_start.to_i}&end=#{aligned_30_sec_end.to_i}".html_safe,
          "http://baw.ecosounds.org/library/#{audio_event.audio_recording_id}/audio_events/#{audio_event.id}"
      ]

      audio_event.tags.order('tags.id ASC').each do |tag|
        audio_event_items.push tag.id, tag.text, tag.type_of_tag, tag.is_taxanomic
      end

      list.push audio_event_items
    end

    list
  end

  # @param [User] current_user
  # @param [Hash] request_params
  def library_format(current_user, request_params)
    request_params[:page] = AudioEvent.filter_count(request_params, :page, 1, 1)
    request_params[:items] = AudioEvent.filter_count(request_params, :items, 10, 1, 30)

    query = AudioEvent.filtered(current_user, request_params)

    response_hash = []

    query.map do |audio_event|
      audio_event_hash = json_format(audio_event)
      response_hash.push(audio_event_hash)
    end

    response_hash
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
end
