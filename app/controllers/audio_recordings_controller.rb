# frozen_string_literal: true

class AudioRecordingsController < ApplicationController
  include Api::ControllerHelper

  # these two methods have custom authorization and include more info in errors
  skip_authorization_check only: [:check_uploader]

  # GET /audio_recordings
  def index
    do_authorize_class

    @audio_recordings, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_recordings(current_user),
      AudioRecording,
      AudioRecording.filter_settings
    )
    respond_index(opts)
  end

  # GET /audio_recordings/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /audio_recordings/new
  # GET /projects/:project_id/sites/:site_id/audio_recordings/new
  def new
    do_new_resource
    get_project_site
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # this is used by the harvester, do not change!
  # POST /projects/:project_id/sites/:site_id/audio_recordings
  def create
    #do_new_resource - custom new audio_recording
    #do_set_attributes(audio_recording_params) - custom set attributes
    @audio_recording = AudioRecording.build_by_file_hash(audio_recording_params)
    get_project_site

    do_authorize_instance

    uploader_id = audio_recording_params[:uploader_id].to_i
    user_exists = User.exists?(uploader_id)
    user = User.where(id: uploader_id).first
    actual_level = Access::Core.user_levels(user, @project)
    requested_level = :writer
    is_allowed = Access::Core.allowed?(requested_level, actual_level)

    if !user_exists || !is_allowed
      respond_error(
        :unprocessable_entity,
        'uploader does not exist or does not have access to this project',
        { error_info: {
          project_id: @project.nil? ? nil : @project.id,
          user_id: user.nil? ? nil : user.id
        } }
      )
    else

      # ensure audio recording has uuid
      @audio_recording.set_uuid

      # check for overlaps and attempt to fix
      overlap_result = @audio_recording.fix_overlaps

      too_many = overlap_result ? overlap_result[:overlap][:too_many] : false
      not_fixed = overlap_result ? overlap_result[:overlap][:items].any? { |info| !info[:fixed] } : false

      Rails.logger.warn overlap_result

      if too_many
        respond_error(:unprocessable_entity, 'Too many overlapping recordings', { error_info: overlap_result })
      elsif not_fixed
        respond_error(:unprocessable_entity, 'Some overlaps could not be fixed', { error_info: overlap_result })
      elsif @audio_recording.save
        respond_create_success
      else
        # @audio_recording.errors.any?
        respond_change_fail
      end

    end
  end

  # this is used by the harvester, do not change!
  # PUT|PATCH /audio_recordings/:id
  def update
    do_load_resource
    do_authorize_instance

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

    additional_keys = relevant_params.to_h.except(file_hash)
    if relevant_params.include?(file_hash) && !additional_keys.empty?
      raise CustomErrors::UnprocessableEntityError.new(
        'If updating file_hash, all other values must match.',
        relevant_params
      )
    elsif relevant_params.include?(file_hash) && additional_keys.empty?
      relevant_params = relevant_params.slice(file_hash)
    else
      # if params does not include file_hash, restrict to valid_keys
      relevant_params = relevant_params.slice(*valid_keys)
    end

    if @audio_recording.update(relevant_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # this is used by the harvester, do not change!
  # GET /projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id
  def check_uploader
    #do_authorize_class - not used, this action does a custom auth
    get_project_site

    # current user should be the harvester
    # uploader_id must have write access to the project

    if current_user.blank?
      raise CanCan::AccessDenied.new(I18n.t('devise.failure.unauthenticated'), :check_uploader, AudioRecording)
    elsif Access::Core.is_harvester?(current_user)
      # auth check is skipped, so auth is checked manually here
      uploader_id = params[:uploader_id].to_i
      user_exists = User.exists?(uploader_id)
      user = User.where(id: uploader_id).first

      actual_level = Access::Core.user_levels(user, @project)
      requested_level = :writer
      is_allowed = Access::Core.allowed?(requested_level, actual_level)

      if !user_exists || !is_allowed
        respond_error(
          :forbidden,
          'uploader does not exist or does not have access to this project',
          { error_info: {
            project_id: @project.nil? ? nil : @project.id,
            user_id: user.nil? ? nil : user.id
          } }
        )
      else
        head :no_content
      end
    else
      respond_error(
        :forbidden,
        'only harvester can check uploader permissions',
        { error_info: {
          project_id: @project.nil? ? nil : @project.id
        } }
      )
    end
  end

  # this is used by the harvester, do not change!
  # this is called by the harvester once the audio file is in the correct location
  # PUT /audio_recordings/:id/update_status
  def update_status
    do_load_resource
    do_authorize_instance

    update_status_user_check
  end

  # GET|POST /audio_recordings/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.audio_recordings(current_user),
      AudioRecording,
      AudioRecording.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def update_status_user_check
    # auth is checked manually here - not sure if this is necessary or not
    if current_user.blank?
      raise CanCan::AccessDenied.new(
        I18n.t('devise.failure.unauthenticated'),
        :update_status_user_check,
        AudioRecording
      )
    elsif Access::Core.is_harvester?(current_user)
      update_status_params_check
    else
      respond_error(:forbidden, 'only harvester can update audio recordings')
    end
  end

  def update_status_params_check
    opts = { error_info: { audio_recording_id: params[:id] } }

    if @audio_recording.blank?
      respond_error(
        :not_found,
        "Could not find Audio Recording with id #{params[:id]}",
        { error_info: { audio_recording_id: params[:id] } }
      )
    elsif !params.include?(:file_hash)
      respond_error(:unprocessable_entity, 'Must include file hash')
    elsif @audio_recording.file_hash != params[:file_hash]
      respond_error(
        :unprocessable_entity,
        'Incorrect file hash',
        { error_info: { audio_recording: { id: params[:id], file_hash: {
          stored: @audio_recording.file_hash,
          request: params[:file_hash]
        } } } }
      )
    elsif !params.include?(:uuid)
      respond_error(:unprocessable_entity, 'Must include uuid')
    elsif @audio_recording.uuid != params[:uuid]
      respond_error(
        :unprocessable_entity,
        'Incorrect uuid',
        { error_info: { audio_recording: { id: params[:id], uuid: {
          stored: @audio_recording.uuid,
          request: params[:uuid]
        } } } }
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
        { error_info: { audio_recording: {
          id: params[:id],
          status: {
            stored: @audio_recording.status,
            request: new_status
          }
        },
                        available_statuses: AudioRecording::AVAILABLE_STATUSES } }
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
    permitted_attributes = [
      :bit_rate_bps,
      :channels,
      :data_length_bytes,
      :original_file_name,
      :duration_seconds,
      :file_hash,
      :media_type,
      :notes,
      :recorded_date,
      :sample_rate_hertz,
      :status,
      :uploader_id,
      :site_id,
      :creator_id,
      { notes: {} }
    ]

    params.require(:audio_recording).permit(*permitted_attributes)
  end

  def get_project_site
    @project = Project.find(params[:project_id]) if params.include?(:project_id)

    @site = Site.find(params[:site_id]) if params.include?(:site_id)

    if defined?(@site) && @site &&
       defined?(@audio_recording) && @audio_recording.site.blank?
      @audio_recording.site = @site
    end
  end
end
