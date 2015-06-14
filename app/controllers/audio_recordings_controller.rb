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
    @audio_recording = AudioRecording.build_by_file_hash(audio_recording_params)
    @audio_recording.site = @site

    uploader_id = audio_recording_params[:uploader_id].to_i
    user_exists = User.exists?(uploader_id)
    user = User.where(id: uploader_id).first
    actual_level = Access::Query.level_project(user, @project)
    requested_level = :writer
    is_allowed = Access::Check.allowed?(requested_level, actual_level)


    if !user_exists || !is_allowed
      respond_error(
          :unprocessable_entity,
          'uploader does not exist or does not have access to this project',
          {error_info: {
              project_id: @project.nil? ? nil : @project.id,
              user_id: user.nil? ? nil : user.id
          }}
      )
    else

      # check for overlaps and attempt to fix
      overlap_result = @audio_recording.fix_overlaps

      too_many = overlap_result ? overlap_result[:overlap][:too_many] : false
      not_fixed = overlap_result ? overlap_result[:overlap][:items].any? { |info| !info[:fixed] } : false

      Rails.logger.warn overlap_result

      if too_many
        respond_error(:unprocessable_entity, 'Too many overlapping recordings', {error_info: overlap_result})
      elsif not_fixed
        respond_error(:unprocessable_entity, 'Some overlaps could not be fixed', {error_info: overlap_result})
      elsif @audio_recording.save
        respond_create_success
      else
        # @audio_recording.errors.any?
        respond_change_fail
      end

    end

  end

  # this is used by the harvester, do not change!
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
    # uploader_id must have write access to the project

    if current_user.blank?
      fail CanCan::AccessDenied.new(I18n.t('devise.failure.unauthenticated'), :check_uploader, AudioRecording)
    elsif Access::Check.is_harvester?(current_user)
        # auth check is skipped, so auth is checked manually here
        uploader_id = params[:uploader_id].to_i
        user_exists = User.exists?(uploader_id)
        user = User.where(id: uploader_id).first

        actual_level = Access::Query.level_project(user, @project)
        requested_level = :writer
        is_allowed = Access::Check.allowed?(requested_level, actual_level)

        if !user_exists || !is_allowed
          respond_error(
              :forbidden,
              'uploader does not exist or does not have access to this project',
              {error_info: {
                  project_id: @project.nil? ? nil : @project.id,
                  user_id: user.nil? ? nil : user.id
              }}
          )
        else
          head :no_content
        end
      else
        respond_error(
            :forbidden,
            'only harvester can check uploader permissions',
            {error_info: {
                project_id: @project.nil? ? nil : @project.id
            }}
        )
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
      fail CanCan::AccessDenied.new(I18n.t('devise.failure.unauthenticated'), :update_status_user_check, AudioRecording)
    elsif Access::Check.is_harvester?(current_user)
      update_status_params_check
    else
      respond_error(:forbidden, 'only harvester can update audio recordings')
    end
  end

  def update_status_params_check
    opts = {error_info: {audio_recording_id: params[:id]}}

    if @audio_recording.blank?
      respond_error(
          :not_found,
          "Could not find Audio Recording with id #{params[:id]}",
          {error_info: {audio_recording_id: params[:id]}})
    elsif !params.include?(:file_hash)
      respond_error(:unprocessable_entity, 'Must include file hash')
    elsif @audio_recording.file_hash != params[:file_hash]
      respond_error(
          :unprocessable_entity,
          'Incorrect file hash',
          {error_info: {audio_recording: {id: params[:id], file_hash: {
              stored: @audio_recording.file_hash,
              request: params[:file_hash]
          }}}}
      )
    elsif !params.include?(:uuid)
      respond_error(:unprocessable_entity, 'Must include uuid')
    elsif @audio_recording.uuid != params[:uuid]
      respond_error(
          :unprocessable_entity,
          'Incorrect uuid',
          {error_info: {audio_recording: {id: params[:id], uuid: {
              stored: @audio_recording.uuid,
              request: params[:uuid]
          }}}}
      )
    elsif !params.include?(:status)
      respond_error(:unprocessable_entity, 'Must include status')
    else
      update_status_available_check
    end
  end

  def update_status_available_check
    new_status = params[:status].to_sym
    if AudioRecording::AVAILABLE_STATUSES_SYMBOLS.include?(new_status)
      update_status_audio_recording(new_status)
    else
      respond_error(
          :unprocessable_entity,
          "Status #{new_status} is not in available status list",
          {error_info: {audio_recording: {
              id: params[:id],
              status: {
                  stored: @audio_recording.status,
                  request: new_status
              }},
                        available_statuses: AudioRecording::AVAILABLE_STATUSES}}
      )
    end
  end

  def update_status_audio_recording(status)
    @audio_recording.status = status
    if @audio_recording.save
      head :no_content
    else
      respond_change_fail
    end
  end

  def audio_recording_params
    params.require(:audio_recording).permit(
        :bit_rate_bps, :channels, :data_length_bytes, :original_file_name,
        :duration_seconds, :file_hash, :media_type, :notes,
        :recorded_date, :sample_rate_hertz, :status, :uploader_id,
        :site_id, :creator_id)
  end

end
