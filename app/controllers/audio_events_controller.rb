require 'csv'

class AudioEventsController < ApplicationController

  load_and_authorize_resource :audio_recording, except: [:new, :library, :library_paged]
  load_and_authorize_resource :audio_event, through: :audio_recording, except: [:new, :library, :library_paged]
  skip_authorization_check only: [:library, :library_paged]
  respond_to :json

  before_filter

  # GET /audio_events
  # GET /audio_events.json
  def index
    if @audio_recording
      event = @audio_recording.audio_events
      event = event.end_after(params[:start_offset]) if params[:start_offset]
      event = event.start_before(params[:end_offset]) if params[:end_offset]
      render json: event.to_json(include: {taggings: {include: :tag}})
    else
      render json: {error: 'An audio recording must be specified.'}, status: :bad_request
    end
  end

  def library
    authorize! :library, AudioEvent
    response_hash = get_audio_events(current_user, params)
    render json: response_hash
  end

  def library_paged
    authorize! :library, AudioEvent
    response_hash = get_audio_events(current_user, params)

    total = AudioEvent.filtered(current_user, params).offset(nil).limit(nil).count

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
    render json: AudioEvent.find(params[:id]).to_json(include: {taggings: {include: :tag}})
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

    project_id = nil
    if params[:project_id]
      project_id = params[:project_id].to_i
    end

    site_id = nil
    if params[:site_id]
      site_id = params[:site_id].to_i
    end

    audio_recording_id = nil
    if params[:audio_recording_id]
      audio_recording_id = params[:audio_recording_id].to_i
    end

    query = AudioEvent.includes(:tags)

    if project_id || site_id

      query = query.joins(audio_recording: {site: :projects})

      query = query.where(projects: {id: project_id}) if project_id

      query = query.where(sites: {id: site_id}) if site_id

    end

    @formatted_annotations =
        custom_format query.order(:recorded_date).all

    respond_to do |format|
      format.xml { render xml: @formatted_annotations }
      format.json { render json: @formatted_annotations }
      format.csv {
        time_now = Time.zone.now
        render_csv("annotations-#{time_now.strftime('%Y%m%d')}-#{time_now.strftime('%H%M%S')}")
      }
    end
  end

  private

  def custom_format(annotations)

    list = []

    annotations.each do |annotation|

      abs_start = annotation.audio_recording.recorded_date.advance(seconds: annotation[:start_time_seconds])
      abs_end = annotation.audio_recording.recorded_date.advance(seconds: annotation[:end_time_seconds])

      annotation_items = [
          annotation[:id],
          abs_start.strftime('%Y/%m/%d'),
          abs_start.strftime('%H:%M:%S'),
          abs_end.strftime('%Y/%m/%d'),
          abs_end.strftime('%H:%M:%S'),
          annotation[:high_frequency_hertz], annotation[:low_frequency_hertz],
          annotation.audio_recording.site.projects.collect { |project| project.id }.join(' | '),
          annotation.audio_recording.site.id,
          annotation.audio_recording.uuid,
          annotation.creator_id,
          'http://localhost:3000/'
      ]

      annotation.tags.each do |tag|
        annotation_items.push tag[:id], tag[:text], tag[:type_of_tag], tag[:is_taxanomic]
      end

      list.push annotation_items
    end

    list
  end

  def get_audio_events(current_user, params)
    params[:page] = AudioEvent.filter_count(params, :page, 1, 1)
    params[:items] = AudioEvent.filter_count(params, :items, 10, 1, 30)

    query = AudioEvent.filtered(current_user, params)

    paging_defaults = AudioEvent.filter_paging_defaults

    response_hash = []

    query.map do |audio_event|
      audio_event_hash = {
          audio_event_id: audio_event.id,
          audio_event_start_date: audio_event.audio_recording.recorded_date.advance(seconds: audio_event.start_time_seconds),
          audio_recording_id: audio_event.audio_recording_id,
          audio_recording_recorded_date: audio_event.audio_recording.recorded_date,
          site_name: audio_event.audio_recording.site.name,
          site_id: audio_event.audio_recording.site.id,
          owner_name: audio_event.owner.user_name,
          owner_id: audio_event.owner.id,
          is_reference: audio_event.is_reference,
          start_time_seconds: audio_event.start_time_seconds,
          end_time_seconds: audio_event.end_time_seconds,
          high_frequency_hertz: audio_event.high_frequency_hertz,
          low_frequency_hertz: audio_event.low_frequency_hertz,
          updated_at: audio_event.updated_at
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

      response_hash.push(audio_event_hash)
    end

    response_hash
  end
end
