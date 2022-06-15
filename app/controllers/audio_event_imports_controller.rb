# frozen_string_literal: true

class AudioEventImportsController < ApplicationController
  include Api::ControllerHelper

  # GET /audio_event_imports
  def index
    do_authorize_class

    respond_to do |format|
      format.json do
        @audio_event_imports, opts = Settings.api_response.response_advanced(
          api_filter_params,
          list_permissions,
          AudioEventImport,
          AudioEventImport.filter_settings
        )
        respond_index(opts)
      end
    end
  end

  # GET /audio_event_imports/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /audio_event_imports/new
  def new
    do_new_resource

    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /audio_event_imports
  def create
    do_new_resource
    do_set_attributes(audio_event_import_params)
    do_authorize_instance

    @audio_event_import.save

    if @audio_event_import.save
      process_file
      respond_create_success(audio_event_import_path(@audio_event_import))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /audio_event_imports/:id
  def update
    do_load_resource
    do_authorize_instance

    process_file

    if has_audio_event_import_params?
      if @audio_event_import.update(audio_event_import_params)

        respond_show
      else
        respond_change_fail
      end
    else
      respond_show
    end
  end

  # DELETE /audio_event_imports/:id
  def destroy
    do_load_resource
    do_authorize_instance

    @audio_event_import.destroy
    add_archived_at_header(@audio_event_import)

    respond_destroy
  end

  # GET|POST /audio_event_imports/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      AudioEventImport,
      AudioEventImport.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def list_permissions
    return AudioEventImport.none if current_user.nil?

    Access::ByUserModified.audio_event_imports(current_user)
  end

  def has_audio_event_import_params?
    params.key?(:audio_event_import)
  end

  def audio_event_import_params
    params
      .require(:audio_event_import)
      .permit(:name, :description)
  end

  def audio_event_import_file_params
    return nil unless params.key?(:import)

    import_params = params
                    .require(:import)
                    .reverse_merge({ additional_tag_ids: [] })
                    .permit(:file, :commit, additional_tag_ids: [])

    import_params[:commit] = ActiveRecord::Type::Boolean.new.deserialize(import_params[:commit])

    return nil if import_params.blank?

    return import_params if import_params[:file].is_a? ActionDispatch::Http::UploadedFile

    raise ActionController::BadRequest, 'the file must be a file uploaded by multipart/form-data'
  end

  # read the file and construct audio events
  # then if all records are valid, and the parent is valid, then save the
  # parent and events in a single transaction
  def process_file
    raise '@audio_event_import must be exist and be saved' if @audio_event_import&.id.nil?

    params = audio_event_import_file_params

    return if params.nil?

    params.to_h => {file:, commit:, additional_tag_ids:}

    additional_tags = (additional_tag_ids || []).map { |tag_id| Tag.find(tag_id) }

    parser = Api::AudioEventParser.new(@audio_event_import, additional_tags:)
    audio_events = parser.parse(file.tempfile.read, file.original_filename).value!

    import_permissions_check(audio_events)

    if commit
      update_model(file.original_filename, additional_tags.map(&:id))
      ActiveRecord::Base.transaction do
        @audio_event_import.save!
        audio_events.each(&:save!)
      end
    else
      audio_events.each(&:valid?)
    end

    # save into model for serialization into response
    @audio_event_import.imported_events = audio_events
  end

  def update_model(filename, tag_ids)
    @audio_event_import.files << {
      name: filename,
      additional_tags: tag_ids,
      imported_at: Time.now
    }
  end

  def import_permissions_check(imported_events)
    attempted_audio_recording_assignments = imported_events.map(&:audio_recording_id).uniq.sort

    ids = Access::ByPermission
          .audio_recordings(current_user, levels: :writer)
          .where(AudioRecording.arel_table[:id].in(attempted_audio_recording_assignments))
          .order(id: :asc)
          .pluck(:id)

    return if (attempted_audio_recording_assignments <=> ids).zero?

    raise CanCan::AccessDenied, 'You do not have permission to add audio events to all audio recordings'
  end
end
