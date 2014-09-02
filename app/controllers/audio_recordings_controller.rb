class AudioRecordingsController < ApplicationController

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
    @audio_recording = match_existing_or_create_new(params)
    @audio_recording.site = @site

    uploader_id = params[:audio_recording][:uploader_id].to_i
    user_exists = User.exists?(uploader_id)
    user = User.where(id: uploader_id).first
    highest_permission = user.highest_permission(@project)

    if !user_exists || highest_permission < AccessLevel::WRITE
      render json: {error: 'uploader does not have access to this project'}.to_json, status: :unprocessable_entity
    elsif check_and_correct_overlap(@audio_recording) && @audio_recording.save
      render json: @audio_recording, status: :created, location: @audio_recording
    else
      render json: @audio_recording.errors, status: :unprocessable_entity
    end
  end

  # this is used by the harvester, do not change!
  def check_uploader
    # current user should be the harvester
    # uploader_id must have read access to the project

    if current_user.blank?
      render json: {error: 'not logged in'}.to_json, status: :unauthorized
    else
      if current_user.has_role? :harvester
        # auth check is skipped, so auth is checked manually here
        uploader_id = params[:uploader_id].to_i
        user_exists = User.exists?(uploader_id)
        user = User.where(id: uploader_id).first
        highest_permission = user.highest_permission(@project)

        if !user_exists || highest_permission < AccessLevel::WRITE
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
    filter_response = api_response.response_filter(
        params,
        AudioRecording,
        AudioRecording.filter_settings
    )
    render_api_response(filter_response)
  end

  private

  def update_status_user_check
    # auth is checked manually here - not sure if this is necessary or not
    if current_user.blank?
      render json: {error: 'not logged in'}.to_json, status: :unauthorized
    elsif current_user.has_role? :harvester
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

  def match_existing_or_create_new(params)
    match = AudioRecording.where(
        original_file_name: params[:audio_recording][:original_file_name],
        file_hash: params[:audio_recording][:file_hash],
        recorded_date: Time.zone.parse(params[:audio_recording][:recorded_date]).utc,
        data_length_bytes: params[:audio_recording][:data_length_bytes],
        media_type: params[:audio_recording][:media_type],
        duration_seconds: params[:audio_recording][:duration_seconds].round(4),
        site_id: params[:audio_recording][:site_id],
        status: 'aborted'
    )

    if match.count == 1
      found = match.first
      found.status = :new
      found
    else
      AudioRecording.new(params[:audio_recording])
    end
  end

  # check and correct overlap. New audio recording is not yet saved.
  # if changes are successfully made by this check, then the
  # check_overlapping validation on audio_recording will succeed.
  # @param [AudioRecording] new_audio_recording
  # @return [Boolean] true if overlaps were checked and corrected, otherwise false
  def check_and_correct_overlap(new_audio_recording)
    if has_overlap(new_audio_recording)
      overlapping = new_audio_recording.overlapping
      overlapping.each do |existing_audio_recording|
        correct_overlap(new_audio_recording, existing_audio_recording)
      end
    end
    true
  end

  # Correct overlap and record changes in notes field for both audio recordings.
  # @param [AudioRecording] new_audio_recording
  # @param [AudioRecording] existing_audio_recording
  def correct_overlap(new_audio_recording, existing_audio_recording)
    existing_audio_recording_start = existing_audio_recording[:recorded_date]
    existing_audio_recording_end = existing_audio_recording[:end_date]
    existing_audio_recording_id = existing_audio_recording[:id]
    existing_audio_recording_uuid = existing_audio_recording[:uuid]

    new_audio_recording_start = new_audio_recording.recorded_date
    new_audio_recording_end = new_audio_recording.recorded_date.advance(seconds: new_audio_recording.duration_seconds)

    if existing_audio_recording_start > new_audio_recording_start
      # if overlap is within threshold, modify new_audio_recording
      overlap_amount = new_audio_recording_end - existing_audio_recording_start
      if overlap_amount <= Settings.audio_recording_max_overlap_sec
        new_audio_recording.duration_seconds = new_audio_recording.duration_seconds - overlap_amount
        notes = new_audio_recording.notes.blank? ? '' : new_audio_recording.notes
        new_audio_recording.notes = notes + create_overlap_notes(overlap_amount, existing_audio_recording_uuid)
      end
    elsif existing_audio_recording_start < new_audio_recording_start
      # if overlap is within threshold, modify existing audio recording
      overlap_amount = existing_audio_recording_end - new_audio_recording_start
      if overlap_amount <= Settings.audio_recording_max_overlap_sec
        existing = AudioRecording.where(id: existing_audio_recording_id).first
        existing.duration_seconds = existing.duration_seconds - overlap_amount
        notes = existing.notes.blank? ? '' : existing.notes
        existing.notes = notes + create_overlap_notes(overlap_amount, new_audio_recording.uuid)
        existing.save!
      end
    end

  end

  def has_overlap(new_audio_recording)
    !new_audio_recording.valid? &&
        new_audio_recording.errors.include?(:recorded_date) &&
        new_audio_recording.errors[:recorded_date].any? { |item| item.include?(:overlapping_audio_recordings) }
  end

  def create_overlap_notes(overlap_amount, other_audio_recording_uuid)
    "\n\"duration_adjustment_for_overlap\"=\"Change made #{Time.zone.now.utc.iso8601}: " +
        "overlap of #{overlap_amount} seconds with audio_recording with uuid #{other_audio_recording_uuid}.\""
  end

end
