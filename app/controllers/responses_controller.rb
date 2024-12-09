# frozen_string_literal: true

class ResponsesController < ApplicationController
  include Api::ControllerHelper

  # GET /responses
  # GET /studies/:study_id/responses
  def index
    do_authorize_class

    @responses, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.responses(current_user, study_id: params[:study_id]),
      Response,
      Response.filter_settings
    )
    respond_index(opts)
  end

  # GET /responses/:id
  def show
    do_load_resource
    do_authorize_instance
    respond_show
  end

  # GET /responses/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.responses(current_user),
      Response,
      Response.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  # GET /responses/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance
    respond_new
  end

  # POST /responses
  # POST /study/:study_id/questions/:question_id/responses
  def create
    do_new_resource
    do_set_attributes(response_params)
    do_authorize_instance

    if @response.save
      respond_create_success(response_path(@response))
    else
      respond_change_fail
    end
  end

  # DELETE /responses/:id
  # Handled in Archivable

  private

  def response_params
    params.require(:response).permit(:study_id, :question_id, :dataset_item_id, :text, :data)
  end
end
