# frozen_string_literal: true

class DatasetsController < ApplicationController
  include Api::ControllerHelper

  # GET /datasets
  def index
    do_authorize_class

    @datasets, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.datasets(current_user),
      Dataset,
      Dataset.filter_settings
    )
    respond_index(opts)
  end

  # GET /datasets/:datasets_id
  def show
    do_load_resource
    do_authorize_instance
    respond_show
  end

  # GET|POST /datasets/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.datasets(current_user),
      Dataset,
      Dataset.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  # GET /datasets/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_show
  end

  # POST /datasets
  def create
    do_new_resource
    do_set_attributes(dataset_params)
    do_authorize_instance

    if @dataset.save
      respond_create_success(dataset_path(@dataset))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /datasets/:id
  def update
    do_load_resource
    do_authorize_instance

    if @dataset.update_attributes(dataset_params)
      respond_show
    else
      respond_change_fail
    end
  end

  private

  def dataset_params
    params.require(:dataset).permit(:description, :name)
  end
end
