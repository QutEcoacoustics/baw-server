class AudioRecordingsController < ApplicationController
  include Api::ControllerHelper

  load_resource :project, only: [:check_uploader, :create]
  load_resource :site, only: [:index, :create]
  skip_authorization_check only: :check_uploader
  load_and_authorize_resource :audio_recording, except: [:check_uploader]
  respond_to :json, except: [:show]

  layout 'player', only: :show

  # GET /audio_recordings.json
  def index

    if @site
      @audio_recordings = @site.audio_recordings.order('recorded_date DESC').limit(5)
    else
      @audio_recordings = AudioRecording.order('recorded_date DESC').limit(5)
    end

    render json: @audio_recordings
  end

  # GET /audio_recordings/1.json
  def show
    render json: @audio_recording
  end

  # GET /audio_recordings/new.json
  def new
    required = [
        :uploader_id,
        :sample_rate_hertz,
        :media_type,
        :recorded_date,
        :bit_rate_bps,
        :data_length_bytes,
        :channels,
        :duration_seconds,
        :file_hash,
        :original_file_name
    ]

    render json: @audio_recording.to_json(only: required)
  end

  # POST /audio_recordings.json
  # this is used by the harvester, do not change!
  def create
    @audio_recording = match_existing_or_create_new
    @audio_recording.site = @site

    uploader_id = audio_recording_params[:uploader_id].to_i
    user_exists = User.exists?(uploader_id)
    user = User.where(id: uploader_id).first
    actual_level = Access::Query.level_project(user, @project)
    requested_level = :writer
    is_allowed = Access::Check.allowed?(requested_level, actual_level)

    if !user_exists || !is_allowed
      render json: {error: 'uploader does not have access to this project'}.to_json, status: :unprocessable_entity
    elsif check_and_correct_overlap(@audio_recording) && @audio_recording.save
      render json: @audio_recording, status: :created, location: @audio_recording
    else
      render json: @audio_recording.errors, status: :unprocessable_entity
    end
  end

  def update

    relevant_params = audio_recording_params

    # can either be one or more of valid_keys, or file_hash only
    file_hash = :file_hash
    valid_keys = [
        :media_type,
        :sample_rate_hertz,
        :channels,
        :bit_rate_bps,
        :data_length_bytes,
        :duration_seconds
    ]

    additional_keys = relevant_params.except(file_hash)
    if relevant_params.include?(file_hash) && additional_keys.size > 0
      fail CustomErrors::UnprocessableEntityError.new(
               'If updating file_hash, all other values must match.',
               relevant_params
           )
    elsif relevant_params.include?(file_hash) && additional_keys.size == 0
      relevant_params = relevant_params.slice(file_hash)
    else
      # if params does not include file_hash, restrict to valid_keys
      relevant_params = relevant_params.slice(*valid_keys)
    end

    if @audio_recording.update_attributes(relevant_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # this is used by the harvester, do not change!
  def check_uploader
    # current user should be the harvester
    # uploader_id must have read access to the project

    if current_user.blank?
      render json: {error: 'not logged in'}.to_json, status: :unauthorized
    else
      if Access::Check.is_harvester?(current_user)
        # auth check is skipped, so auth is checked manually here
        uploader_id = params[:uploader_id].to_i
        user_exists = User.exists?(uploader_id)
        user = User.where(id: uploader_id).first

        actual_level = Access::Query.level_project(user, @project)
        requested_level = :writer
        is_allowed = Access::Check.allowed?(requested_level, actual_level)

        if !user_exists || !is_allowed
          render json: {error: 'uploader does not have access to this project'}.to_json, status: :ok
        else
          head :no_content
        end
      else
        render json: {error: 'only harvester can check uploader permissions'}.to_json, status: :forbidden
      end
    end
  end

  # this is called by the harvester once the audio file is in the correct location
  # this is used by the harvester, do not change!
  def update_status
    update_status_user_check
  end

  # POST /audio_recordings/filter.json
  # GET /audio_recordings/filter.json
  def filter
    authorize! :filter, AudioRecording
    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::Query.audio_recordings(current_user, Access::Core.levels_allow),
        AudioRecording,
        AudioRecording.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def update_status_user_check
    # auth is checked manually here - not sure if this is necessary or not
    if current_user.blank?
      render json: {error: 'not logged in'}.to_json, status: :unauthorized
    elsif Access::Check.is_harvester?(current_user)
      update_status_params_check
    else
      render json: {error: 'only harvester can check uploader permissions'}.to_json, status: :forbidden
    end
  end

  def update_status_params_check
    if @audio_recording.blank?
      render json: {error: "Could not find Audio Recording with id #{params[:id]}"}.to_json, status: :not_found
    elsif !params.include?(:file_hash)
      render json: {error: 'Must include file hash'}.to_json, status: :unprocessable_entity
    elsif @audio_recording.file_hash != params[:file_hash]
      render json: {error: 'Incorrect file hash'}.to_json, status: :unprocessable_entity
    elsif !params.include?(:uuid)
      render json: {error: 'Must include uuid'}.to_json, status: :unprocessable_entity
    elsif @audio_recording.uuid != params[:uuid]
      render json: {error: 'Incorrect uuid'}.to_json, status: :unprocessable_entity
    elsif !params.include?(:status)
      render json: {error: 'Must include status'}.to_json, status: :unprocessable_entity
    else
      update_status_available_check
    end
  end

  def update_status_available_check
    new_status = params[:status].to_sym
    if AudioRecording::AVAILABLE_STATUSES_SYMBOLS.include?(new_status)
      update_status_audio_recording(new_status)
    else
      render json: {error: "Status #{new_status} is not in available status list #{AudioRecording::AVAILABLE_STATUSES_SYMBOLS}."}.to_json, status: :unprocessable_entity
    end
  end

  def update_status_audio_recording(status)
    @audio_recording.status = status
    if @audio_recording.save!
      head :no_content
    else
      render json: @audio_recording.errors, status: :unprocessable_entity
    end
  end

  def match_existing_or_create_new
    the_params = audio_recording_params
    match = AudioRecording.where(
        original_file_name: the_params[:original_file_name],
        file_hash: the_params[:file_hash],
        recorded_date: Time.zone.parse(the_params[:recorded_date]).utc,
        data_length_bytes: the_params[:data_length_bytes],
        media_type: the_params[:media_type],
        duration_seconds:the_params[:duration_seconds].round(4),
        site_id: the_params[:site_id],
        status: 'aborted'
    )

    if match.count == 1
      found = match.first
      found.status = :new
      found
    else
      AudioRecording.new(the_params)
    end
  end

  # check and correct overlap. New audio recording is not yet saved.
  # if changes are successfully made by this check, then the
  # check_overlapping validation on audio_recording will succeed.
  # @param [AudioRecording] new_audio_recording
  # @return [Boolean] true if overlaps were checked and corrected, otherwise false
  def check_and_correct_overlap(new_audio_recording)
    if AudioRecordingOverlap.any?(new_audio_recording)
      AudioRecordingOverlap.fix(new_audio_recording, Settings.audio_recording_max_overlap_sec)
    end
    true
  end

  def audio_recording_params
    params.require(:audio_recording).permit(
        :bit_rate_bps, :channels, :data_length_bytes, :original_file_name,
        :duration_seconds, :file_hash, :media_type, :notes,
        :recorded_date, :sample_rate_hertz, :status, :uploader_id,
        :site_id, :creator_id)
  end

end
