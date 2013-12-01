class AudioEventsController < ApplicationController

  load_and_authorize_resource :audio_recording, except: [:new]
  load_and_authorize_resource :audio_event, through: :audio_recording, except: [:new]
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
      render json: AudioEvent.all.to_json(include: {taggings: {include: :tag}})
    end
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

    render json: @audio_event.to_json(only: [:start_time_seconds, :end_time_seconds, :low_frequency_hertz, :high_frequency_hertz, :is_reference] )
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
      project_id = Integer(params[:project_id].to_s, 10)
    end

    site_id = nil
    if params[:site_id]
      site_id = Integer(params[:site_id].to_s, 10)
    end

    query = AudioEvent.includes(:tags)

    if project_id || site_id

      query =  query.joins(audio_recording: {site: :projects})

      query = query.where(projects: {id: project_id}) if project_id

      query = query.where(sites: {id: site_id}) if site_id

    end

    @formatted_annotations =
        custom_format query.order(:audio_event => :recorded_date).all

    respond_to do |format|
      format.xml { render :xml => @formatted_annotations  }
      format.json { render :json => @formatted_annotations }
      format.csv  {
        time_now = Time.zone.now
        render_csv("annotations-#{time_now.strftime("%Y%m%d")}-#{time_now.strftime("%H%M%S")}")
}
    end
  end

  private

  def custom_format(annotations)

    list = []

    annotations.each do |annotation|

      annotation_items = [
          annotation[:id],
          annotation.audio_recording.recorded_date.advance(:seconds => annotation[:start_time_seconds]).strftime('%Y/%m/%d'),
          annotation.audio_recording.recorded_date.advance(:seconds => annotation[:start_time_seconds]).strftime('%H:%M:%S'),
          annotation.audio_recording.recorded_date.advance(:seconds => annotation[:end_time_seconds]).strftime('%Y/%m/%d'),
          annotation.audio_recording.recorded_date.advance(:seconds => annotation[:end_time_seconds]).strftime('%H:%M:%S'),
          annotation[:high_frequency_hertz], annotation[:low_frequency_hertz],
          annotation.audio_recording.site.projects.collect{ |project| project.id }.join(' | '),
          annotation.audio_recording.site.id,
          annotation.audio_recording.uuid,
          annotation.creator_id,
          'http://localhost:3000/'
      ]

      annotation.tags.each do |tag|
        annotation_items.push  tag[:id], tag[:text],tag[:type_of_tag], tag[:is_taxanomic]
      end

      list.push annotation_items
    end

    list
  end
end
