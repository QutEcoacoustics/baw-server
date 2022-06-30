# frozen_string_literal: true

# Controller for Harvests
class HarvestItemsController < ApplicationController
  include Api::ControllerHelper

  # GET /harvests/:harvest_id/items(/:path)
  # GET /projects/:project_id/harvests/:harvest_id/items(/:path)
  def index
    do_authorize_class
    get_project_if_exists
    get_harvest_if_exists

    path = params[:path] || ''
    path = @harvest.harvester_relative_path(path)

    respond_to { |format|
      query =  HarvestItem.includes([:harvest]).project_directory_listing(list_permissions, path)
      format.json do
        @harvest_items, opts = Settings.api_response.response_advanced(
          api_filter_params,
          query,
          HarvestItem,
          HarvestItem.filter_settings
        )

        respond_index(opts)
      end
    }
  end

  # GET|POST /harvests/:harvest_id/items/filter
  # GET|POST /projects/:project_id/harvests/:harvest_id/items/filter
  def filter
    do_authorize_class
    get_project_if_exists
    get_harvest_if_exists

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      HarvestItem,
      HarvestItem.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def get_project_if_exists
    @project = nil
    return unless params.key?(:project_id)

    @project = Project.find(params[:project_id])
  end

  def get_harvest_if_exists
    @harvest = nil

    return unless params.key?(:harvest_id)

    @harvest = Harvest.find(params[:harvest_id])
  end

  def list_permissions
    if @project&.id&.present? && @project.id != @harvest&.project_id
      raise "Invalid route parameters; project_id does not match harvest's project_id"
    end

    harvest_id = @harvest&.id
    raise 'Invalid route parameters; harvest_id is nil' unless harvest_id

    # we always use information from the parent harvest
    Access::ByPermission.harvest_items(current_user, harvest_id:).includes([:harvest])
  end
end
