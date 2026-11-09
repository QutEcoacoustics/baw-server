# frozen_string_literal: true

class ExportsController < ApplicationController
  include Api::ControllerHelper

  # A user with a valid token can access the action without authorization.
  skip_authorization_check only: [:download]

  def should_authenticate_user?
    return false if action_sym == :download

    super
  end

  # GET /exports
  def index
    do_authorize_class

    @exports, opts = Settings.api_response.response_advanced(
      api_filter_params,
      accessible_exports,
      Export,
      Export.filter_settings
    )
    respond_index(opts)
  end

  # GET /exports/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /exports/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /exports
  # Create an export and enqueue it for background processing.
  # Returns a token and exchange_url (download url + token) for downloading the export.
  # The token is used to authenticate the download request without requiring the user to be logged in.
  def create
    do_new_resource
    do_set_attributes(export_params)

    do_authorize_instance

    if @export.save
      @export.enqueue!

      token = @export.signed_id(purpose: :export_download)
      respond_create_success(
        export_path(@export),
        { token:, exchange_url: download_export_url(@export, token:) }
      )
    else
      respond_change_fail
    end
  end

  # DELETE /exports/:id
  # Handled in Archivable
  # Using callback defined in Archivable
  before_destroy do
    next unless @export.status_queued? || @export.status_working?

    respond_error(:conflict, "Cannot be deleted while `status` is `#{@export.status}`")
  end

  # GET|POST /exports/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      accessible_exports,
      Export,
      Export.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def export_params
    params.require(:export).permit(
      :export_type,
      :name,
      :obfuscate_locations,
      :project_id,
      filter: {},
      options: {}
    )
  end

  # GET /exports/:id/download
  #
  # Who can download an export:
  #
  # Step 1: find the export.
  # - With a `token` param: the token identifies the export. Anyone with a valid token
  #   can continue, with no login needed.
  # - Without a token: the user must be logged in and must be the export's creator.
  #
  # Step 2: check the creator is still allowed to have this export (token or not).
  # Any reader or above can create an export, but permissions can change afterwards,
  # so we check the creator's *current* access to the project:
  # - They must still be a reader or above.
  # - If the export has `obfuscate_locations: false`, they must still be an owner.
  # If not, the download is denied. See {Export#creator_can_download?}.
  def download
    do_load_resource
    do_authorize_instance unless download_token?
    raise CanCan::AccessDenied, 'The export creator no longer has permission to download this export' unless
      @export.creator_can_download?

    raise CustomErrors::GoneError, 'The export has expired or was purged' if export_file_gone?

    if @export.status_failed?
      raise CustomErrors::UnprocessableEntityError.new(@export.error,
        { export_id: @export.id, status: @export.status })
    end

    unless @export.status_ready?
      return respond_error(:service_unavailable,
        'The export is not ready yet. Try again later.')
    end

    Export.increment_counter(:download_count, @export.id) # rubocop:disable Rails/SkipsModelValidations -- atomic counter update

    blob = @export.file.blob

    send_file(
      blob.service.path_for(blob.key),
      filename: blob.filename.to_s,
      type: 'application/zip',
      disposition: 'attachment'
    )
  end

  private

  def download_token?
    params[:token].present?
  end

  # Load the current resource. Patched to find the export from a download token when one is sent.
  # The export retrieved from the token must match the ID in the request parameters.
  def do_load_resource
    return super unless action_sym == :download && download_token?

    export = Export.find_signed!(params[:token], purpose: :export_download)
    raise ActiveRecord::RecordNotFound unless export.id.to_s == params[:id]

    set_resource(export)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise ActiveRecord::RecordNotFound
  end

  def export_file_gone?
    @export.status_ready? && (@export.purged? || @export.expires_at&.past?)
  end

  def accessible_exports
    Access::ByUserModified.exports(current_user)
  end
end
