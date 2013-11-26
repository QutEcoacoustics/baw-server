require './lib/modules/mime'
require './lib/modules/media_cacher'

class AudioRecordingsController < ApplicationController
  include MediaCacher, Mime

  load_resource :project, only: [:check_uploader, :create]
  load_resource :site, only: [:check_uploader, :create]
  load_and_authorize_resource :audio_recording

  layout 'player', only: :show


  # GET /audio_recordings.json
  def index

    if @site
      @audio_recordings = @site.audio_recordings
    else
      @audio_recordings = AudioRecording.all
    end

    render json: @audio_recordings
  end

  # GET /audio_recordings/1.json
  def show

    respond_to do |format|
      format.html {}
      format.json { render json: @audio_recording }
    end
  end

  # GET /audio_recordings/new.json
  def new
    @audio_recording = AudioRecording.new

    render json: @audio_recording.to_json(only: [:uploader_id, :sample_rate_hertz, :media_type, :recorded_date, :bit_rate_bps, :data_length_bytes, :channels, :duration_seconds] )
  end


  # POST /audio_recordings.json
  def create
    @audio_recording = AudioRecording.new(params[:audio_recording])
    @audio_recording.site = @site

    if !User.exists?(params[:audio_recording][:uploader_id]) || !User.find(params[:audio_recording][:uploader_id]).can_write?(@project)
      render json: {error:'uploader does not have access to this project'}.to_json, status: :unprocessable_entity
    elsif @audio_recording.save
      render json: @audio_recording, status: :created, location: [@project, @site, @audio_recording]
    else
      render json: @audio_recording.errors, status: :unprocessable_entity
    end

  end

  def check_uploader
    if !User.exists?(params[:uploader_id]) || !User.find(params[:uploader_id]).can_write?(@project)
      render json: {error:'uploader does not have access to this project'}.to_json, status: :unprocessable_entity
    else
      head :no_content
    end
  end

  ## PUT /audio_recordings/1.json
  #def update
  #  @audio_recording = AudioRecording.find(params[:id])
  #
  #  respond_to do |format|
  #    if @audio_recording.update_attributes(params[:audio_recording])
  #      format.json { head :no_content }
  #    else
  #      format.json { render json: @audio_recording.errors, status: :unprocessable_entity }
  #    end
  #  end
  #end
  #
  ## DELETE /audio_recordings/1.json
  #def destroy
  #  @audio_recording = AudioRecording.find(params[:id])
  #  @audio_recording.destroy
  #
  #  add_archived_at_header(@audio_recording)
  #
  #  respond_to do |format|
  #    format.json { no_content_as_json }
  #  end
  #end

  # this is called by the harvester once the audio file is in the correct location
  def update_status

    @audio_recording.status = :ready
    if @audio_recording.blank?
      render json: {error:"Could not find Audio Recording with id #{params[:id]}"}.to_json, status: :not_found
    elsif @audio_recording.file_hash != params[:audio_recording][:file_hash]
      render json: {error:"Incorrect file_hash #{params[:audio_recording][:file_hash]}"}.to_json, status: :unprocessable_entity
    elsif @audio_recording.uuid != params[:audio_recording][:uuid]
      render json: {error:"Incorrect uuid #{params[:audio_recording][:uuid]}"}.to_json, status: :unprocessable_entity
    elsif @audio_recording.save!
      head :no_content
    else
      head :bad_request
    end
  end

end
