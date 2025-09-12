# frozen_string_literal: true

# Manages file artifacts for an audio event import.
# Can either be an uploaded file or a link to an analysis job result
class AudioEventImportFilesController < ApplicationController
  include Api::ControllerHelper

  # GET /audio_event_imports/:audio_event_import_id/files
  def index
    do_authorize_class
    get_audio_event_import(for_list_endpoint: true)

    @audio_event_import_files, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      AudioEventImportFile,
      AudioEventImportFile.filter_settings
    )

    respond_index(opts)
  end

  # GET /audio_event_imports/:audio_event_import_id/files/:id
  def show
    do_load_resource
    get_audio_event_import(for_list_endpoint: false)
    do_authorize_instance

    respond_show
  end

  # GET /audio_event_imports/:audio_event_import_id/files/new
  def new
    do_new_resource

    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /audio_event_imports/:audio_event_import_id/files
  def create
    do_new_resource
    get_audio_event_import(create: true)
    params = audio_event_import_file_params
    do_set_attributes(params)

    do_authorize_instance

    return respond_change_fail unless @audio_event_import_file.valid?

    # process the file
    # After this the @audio_event_import_file may or may not be saved
    imported_events, result = process_file(params[:file])

    additional_data = {
      imported_events:,
      committed: commit?
    }

    if result.failure?
      @audio_event_import_file.errors.add(:file, result.failure)
      return respond_change_fail_with_resource(additional_data)
    end

    if commit?
      # if not saved mimic a show response, otherwise return created status (201)
      path = audio_event_import_file_path(@audio_event_import, @audio_event_import_file)
      respond_create_success(path, additional_data)
    else
      respond_show(additional_data)
    end
  end

  #
  # no update method
  #

  # DELETE /audio_event_imports/:audio_event_import_id/files/:id
  # Handled in Archivable
  # Using callback defined in Archivable
  before_destroy do
    get_audio_event_import(for_list_endpoint: false)
  end

  # GET|POST /audio_event_imports/:audio_event_import_id/files/filter
  def filter
    do_authorize_class
    get_audio_event_import(for_list_endpoint: true)

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      AudioEventImportFile,
      AudioEventImportFile.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def get_audio_event_import(for_list_endpoint: false, create: false)
    @audio_event_import ||= AudioEventImport.find(params[:audio_event_import_id])

    raise ActiveRecord::RecordNotFound, 'AudioEventImport does not exist' if @audio_event_import.nil?

    return if for_list_endpoint

    if create
      # create case
      @audio_event_import_file.audio_event_import = @audio_event_import
      return
    end

    # show/delete case
    return if @audio_event_import.id == @audio_event_import_file.audio_event_import_id

    raise CustomErrors::RoutingArgumentError,
      'audio_event_import_file must belong to the audio_event_import'
  end

  def list_permissions
    Access::ByUserModified.audio_event_import_files(@audio_event_import, current_user)
  end

  def commit?
    @commit ||= ActiveRecord::Type::Boolean.new.deserialize(params[:commit])
  end

  def provenance
    return nil if params[:provenance_id].blank?

    @provenance ||= Provenance.find(params[:provenance_id])
  rescue ActiveRecord::RecordNotFound
    raise CustomErrors::ItemNotFoundError, "Provenance not found for id: #{params[:provenance_id]}"
  end

  def audio_event_import_file_params
    import_params = params
      .require(:audio_event_import_file)
      .reverse_merge({ additional_tag_ids: [], minimum_score: nil })
      .permit(:file, :audio_event_import_id, :minimum_score, additional_tag_ids: [])

    import_params[:additional_tag_ids] =
      validate_params_array_of_ids(name: 'additional_tag_ids', value: import_params[:additional_tag_ids])

    import_params[:minimum_score] = BigDecimal(import_params[:minimum_score]) if import_params[:minimum_score].present?

    return import_params.to_h if import_params[:file].is_a? ActionDispatch::Http::UploadedFile

    raise ActionController::BadRequest, 'the file must be a file uploaded by multipart/form-data'
  end

  # read the file and construct audio events
  # then if all records are valid, and the parent is valid, then save the
  # parent and events in a single transaction
  # @return [Array(Array<AudioEvent>, ::Dry::Monads::Result] the audio events and the result of the parsing
  def process_file(file)
    parser = Api::AudioEventParser.new(
      @audio_event_import_file,
      current_user,
      additional_tags: @audio_event_import_file.additional_tags,
      provenance:,
      score_minimum: @audio_event_import_file.minimum_score
    )

    if commit?
      parser.parse_and_commit(file.tempfile.read, file.original_filename)
    else
      parser.parse(file.tempfile.read, file.original_filename)
    end => result

    # return for serialization into response
    [parser.serialize_audio_events, result]
  end
end
