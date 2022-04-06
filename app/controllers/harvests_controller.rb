# frozen_string_literal: true

# Controller for Harvests
class HarvestsController < ApplicationController
  include Api::ControllerHelper

  # GET /harvests
  # GET /projects/:project_id/harvests
  def index
    do_authorize_class
    get_project_if_exists
    do_authorize_instance(:show, @project) unless @project.nil?

    respond_to do |format|
      format.json do
        @harvests, opts = Settings.api_response.response_advanced(
          api_filter_params,
          list_permissions,
          Harvest,
          Harvest.filter_settings
        )
        respond_index(opts)
      end
    end
  end

  # GET /harvests/:id
  # GET /projects/:project_id/harvests/:id
  def show
    do_load_resource
    get_project_if_exists
    do_authorize_instance

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
    do_set_attributes(harvest_params)
    get_project_if_exists
    do_authorize_instance

    if @harvest.save

      @harvest.open_upload!

      if @project.nil?
        respond_create_success(shallow_region_path(@harvest))
      else
        respond_create_success(project_region_path(@project, @harvest))
      end
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

    parameters = harvest_params(update: true)

    # allow the API to transition this harvest to a new state
    status = parameters.delete(:status)
    @harvest.transition_to_state(status.to_sym) unless status.nil?

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
    get_project_if_exists
    do_authorize_instance(:show, @project) unless @project.nil?

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      Harvest,
      Harvest.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def get_project_if_exists
    return unless params.key?(:project_id)

    @project = Project.find(params[:project_id])
    @harvest.project = @project if defined?(@harvest) && defined?(@project)
  end

  def list_permissions
    if @project.nil?
      Access::ByPermission.harvests(current_user)
    else
      Access::ByPermission.harvests(current_user, project_id: @project.id)
    end
  end

  def harvest_params(update: false)
    harvest = params.require(:harvest)

    # TODO: sanitize mappings object
    raise 'incomplete' if harvest.key?(:mappings)

    other = []
    other << :project_id unless update
    other << :status if upcase

    harvest.permit(:mappings, :state, *other)
  end
end
