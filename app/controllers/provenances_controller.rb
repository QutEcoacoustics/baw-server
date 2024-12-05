# frozen_string_literal: true

class ProvenancesController < ApplicationController
  include Api::ControllerHelper

  # GET /provenances
  def index
    do_authorize_class

    @provenances, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.provenances(current_user),
      Provenance,
      Provenance.filter_settings
    )

    respond_index(opts)
  end

  # GET /provenances/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /provenances/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /provenances
  def create
    do_new_resource
    do_set_attributes(project_params)
    do_authorize_instance

    if @provenance.save
      respond_create_success(provenance_path(@provenance))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /provenances/:id
  def update
    do_load_resource
    do_authorize_instance

    if @provenance.update(project_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /provenances/:id
  # Handled in Archivable

  # GET|POST /provenances/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.provenances(current_user),
      Provenance,
      Provenance.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def project_params
    params.require(:provenance).permit(
      :name, :version, :url, :description, :score_minimum, :score_maximum
    )
  end

  def update_params
    params.require(:provenance).permit(
      :name, :version, :url, :description, :score_minimum, :score_maximum
    )
  end
end
