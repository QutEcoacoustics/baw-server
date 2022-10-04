# frozen_string_literal: true

# Controller for Harvests
class HarvestsController < ApplicationController
  include Api::ControllerHelper

  # GET /harvests
  # GET /projects/:project_id/harvests
  def index
    do_authorize_class
    get_project_if_exists(for_list_endpoint: true)
    do_authorize_instance(:show, @project) unless @project.nil?

    @harvests, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      Harvest,
      Harvest.filter_settings
    )

    respond_index(opts)
  end

  # GET /harvests/:id
  # GET /projects/:project_id/harvests/:id
  def show
    do_load_resource
    get_project_if_exists
    do_authorize_instance

    # pump the state machine if one of the processing states is active
    # not technically idempotent but we need some method to advance the state machine
    # TODO: should do this in the harvest process too!
    @harvest.transition_from_computing_to_review_if_needed!

    @harvest.extend_upload_user_expiry_if_needed!

    respond_show
  end

  # GET /harvests/new
  # GET /projects/:project_id/harvests/new
  def new
    do_new_resource
    get_project_if_exists
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /harvests
  # POST /projects/:project_id/harvests
  def create
    do_new_resource
    parameters = harvest_params
    sanitize_mappings(parameters)

    do_set_attributes(parameters)
    get_project_if_exists
    do_authorize_instance

    if @harvest.save

      begin
        @harvest.open_upload!
      rescue BawWorkers::UploadService::UploadServiceError
        @harvest.destroy
        raise
      end

      respond_create_success(project_harvest_path(@harvest.project, @harvest))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /harvests/:id
  # PUT|PATCH /projects/:project_id/harvests/:id
  def update
    do_load_resource
    get_project_if_exists
    do_authorize_instance

    # disallow any update if we're in a processing state
    unless @harvest.update_allowed?
      raise CustomErrors::MethodNotAllowedError.new(
        "Cannot update a harvest while it is #{@harvest.status}",
        [:post, :put, :patch, :delete]
      )
    end

    parameters = harvest_params(update: true)
    sanitize_mappings(parameters)

    # use a row-level lock to prevent concurrent updates - especially for race conditions
    # that can occur while talking with other services (e.g. sftpgo)
    # https://blog.saeloun.com/2022/03/23/rails-7-adds-lock_with.html
    # This could cause performance issues: monitor.
    # AT 2022: disabled for now as it seems to be causing race conditions - other code further down the stack locks for
    # with a transaction that needs to be visible to external actors before this method completed
    # allow the API to transition this harvest to a new state
    #@harvest.with_lock('FOR UPDATE') do end

    status = parameters.delete(:status)
    @harvest.transition_to_state!(status.to_sym) unless status.nil?

    if @harvest.update(parameters)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /harvests/:id
  # DELETE /projects/:project_id/harvests/:id
  def destroy
    do_load_resource
    get_project_if_exists
    do_authorize_instance

    @harvest.destroy
    add_archived_at_header(@harvest)

    respond_destroy
  end

  # GET|POST /harvests/filter
  # GET|POST /projects/:project_id/harvests/filter
  def filter
    do_authorize_class
    get_project_if_exists(for_list_endpoint: true)
    do_authorize_instance(:show, @project) unless @project.nil?

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      Harvest,
      Harvest.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def get_project_if_exists(for_list_endpoint: false)
    return unless params.key?(:project_id)

    @project = Project.find(params[:project_id])

    return if for_list_endpoint

    raise '@harvest must be defined' unless defined?(@harvest)

    if @harvest.project_id.nil?
      @harvest.project = @project
      return
    end

    return if @project.id == @harvest.project_id

    raise CustomErrors::RoutingArgumentError.new, 'project_id in route does not match the harvest\'s project_id'
  end

  def list_permissions
    Access::ByPermission.harvests(current_user, project_id: @project&.id)
  end

  def sanitize_mappings(parameters)
    mappings = parameters[:mappings]

    return parameters if mappings.blank?

    parameters[:mappings] = mappings.map { |mapping|
      BawWorkers::Jobs::Harvest::Mapping.new(mapping)
    }

    parameters
  rescue ::Dry::Struct::Error => e
    raise CustomErrors::UnprocessableEntityError, "Invalid mapping: #{e.message}"
  end

  def harvest_params(update: false)
    harvest = params.require(:harvest)

    permitted = [:name]
    permitted << :project_id unless update
    permitted << :status if update
    permitted << :streaming unless update

    permitted << ({
      # allow an array
      # of object which have primitive scalar values with keys that equal attribute names
      mappings: [BawWorkers::Jobs::Harvest::Mapping.attribute_names]
    })
    harvest.permit(*permitted)
  end
end
