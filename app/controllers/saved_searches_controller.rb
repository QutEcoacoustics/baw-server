class SavedSearchesController < ApplicationController
  include Api::ControllerHelper

  # order matters for before_action and load_and_authorize_resource!
  load_and_authorize_resource :saved_search, except: [:filter]

  # this is necessary so that the ability has access to permission.project
  before_action :build_saved_search, only: [:new, :create]

  # GET /saved_searches
  # GET /saved_searches.json
  def index
    @saved_searches, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_saved_searches,
        SavedSearch,
        SavedSearch.filter_settings
    )
    respond_index(opts)
  end

  # GET /saved_searches/1
  # GET /saved_searches/1.json
  def show
    respond_show
  end

  # GET /saved_searches/new
  # GET /saved_searches/new.json
  def new
    do_authorize!

    respond_show
  end

  # POST /saved_searches
  # POST /saved_searches.json
  def create
    attributes_and_authorize(saved_search_params)

    @saved_search.projects = @saved_search.extract_projects(current_user)

    if @saved_search.save
      respond_create_success(saved_search_url(@saved_search))
    else
      respond_change_fail
    end

  end

  # DELETE /saved_searches/1
  # DELETE /saved_searches/1.json
  def destroy
    @saved_search.destroy
    add_archived_at_header(@saved_search)
    respond_destroy
  end

  def filter
    authorize! :filter, SavedSearch
    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_saved_searches,
        SavedSearch,
        SavedSearch.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def build_saved_search
    @saved_search = SavedSearch.new
  end

  def saved_search_params
    params.require(:saved_search).permit(:id, :name, :description, :stored_query)
  end

  def get_saved_searches
    Access::Query.saved_searches(current_user, Access::Core.levels_allow)
  end

end
