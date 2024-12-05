# frozen_string_literal: true

class SavedSearchesController < ApplicationController
  include Api::ControllerHelper

  # GET /saved_searches.json
  def index
    do_authorize_class

    @saved_searches, opts = Settings.api_response.response_advanced(
      api_filter_params,
      get_saved_searches,
      SavedSearch,
      SavedSearch.filter_settings
    )
    respond_index(opts)
  end

  # GET /saved_searches/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /saved_searches/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /saved_searches
  def create
    do_new_resource
    do_set_attributes(saved_search_params)

    @saved_search.projects_populate(current_user)

    do_authorize_instance

    if @saved_search.save
      respond_create_success
    else
      respond_change_fail
    end
  end

  # DELETE /saved_searches/:id
  # Handled in Archivable

  # GET|POST /saved_searches/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      get_saved_searches,
      SavedSearch,
      SavedSearch.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def saved_search_params
    params.require(:saved_search).permit(:id, :name, :description, stored_query: {})
  end

  def get_saved_searches
    Access::ByPermission.saved_searches(current_user)
  end
end
