# frozen_string_literal: true

class StudiesController < ApplicationController
  include Api::ControllerHelper

  # GET /studies
  def index
    do_authorize_class

    @studies, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Study.all,
      Study,
      Study.filter_settings
    )
    respond_index(opts)
  end

  # GET /studies/:id
  def show
    do_load_resource
    do_authorize_instance
    respond_show
  end

  # GET /studies/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Study.all,
      Study,
      Study.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_show
  end

  # POST /studies/
  def create
    do_new_resource
    do_set_attributes(study_params)
    do_authorize_instance

    if @study.save
      respond_create_success(study_path(@study))
    else
      respond_change_fail
    end
  end

  # PUT /studies/:id
  def update
    do_load_resource
    do_authorize_instance

    if @study.update_attributes(study_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /studies/:id
  def destroy
    do_load_resource
    do_authorize_instance
    @study.destroy
    respond_destroy
  end

  private

  def study_params
    # params[:study] = params[:study] || {}
    # params[:study][:dataset_id] = params[:dataset_id]
    params.require(:study).permit(:dataset_id, :name)
  end
end
