# frozen_string_literal: true

# Controller for Regions
class RegionsController < ApplicationController
  include Api::ControllerHelper

  # GET /regions
  # GET /projects/:project_id/regions
  def index
    do_authorize_class
    get_project_if_exists
    do_authorize_instance(:show, @project) unless @project.nil?

    respond_to do |format|
      format.json do
        @regions, opts = Settings.api_response.response_advanced(
          api_filter_params,
          list_permissions,
          Region,
          Region.filter_settings
        )
        respond_index(opts)
      end
    end
  end

  # GET /regions/:id
  # GET /projects/:project_id/regions/:id
  def show
    do_load_resource
    get_project_if_exists
    do_authorize_instance

    respond_show
  end

  # GET /regions/new
  # GET /projects/:project_id/regions/new
  def new
    do_new_resource
    get_project_if_exists
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /regions
  # POST /projects/:project_id/regions
  def create
    do_new_resource
    do_set_attributes(region_params)
    get_project_if_exists
    do_authorize_instance

    if @region.save
      if @project.nil?
        respond_create_success(shallow_region_path(@region))
      else
        respond_create_success(project_region_path(@project, @region))
      end
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /regions/:id
  # PUT|PATCH /projects/:project_id/regions/:id
  def update
    do_load_resource
    get_project_if_exists
    do_authorize_instance

    @original_region_name = @region.name

    if @region.update(region_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /regions/:id
  # DELETE /projects/:project_id/regions/:id
  # Handled in Archivable
  # Using callback defined in Archivable
  before_destroy do
    get_project_if_exists
  end

  # GET|POST /regions/filter
  # GET|POST /projects/:project_id/regions/filter
  def filter
    do_authorize_class
    get_project_if_exists
    do_authorize_instance(:show, @project) unless @project.nil?

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      Region,
      Region.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def get_project_if_exists
    return unless params.key?(:project_id)

    @project = Project.find(params[:project_id])
    @region.project = @project if defined?(@region) && defined?(@project)
  end

  def list_permissions
    if @project.nil?
      Access::ByPermission.regions(current_user).includes([:image_attachment])
    else
      Access::ByPermission.regions(current_user, project_id: @project.id).includes([:image_attachment])
    end
  end

  def region_params
    sanitize_associative_array(:tag, :notes)

    wrapper = params.require(:region)

    # form data munges json objects, so disallow notes being updated in these cases
    if request.form_data?
      wrapper.permit(:name, :description, :notes, :project_id, :image)
    else
      wrapper.permit(:name, :description, :notes, :project_id, :image, notes: {})
    end
  end
end
