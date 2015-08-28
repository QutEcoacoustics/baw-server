class SavedSearchesController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource :saved_search, except: [:filter]

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

  # GET /saved_searches/1.json
  def show
    respond_show
  end

  # GET /saved_searches/new.json
  def new
    respond_show
  end

  # POST /saved_searches.json
  def create
    if @saved_search.save

      # TODO add logging and timing
      # TODO This may need to be async depending on how fast it runs
      @saved_search.projects_populate(current_user)

      respond_create_success
    else
      respond_change_fail
    end

  end

  # DELETE /saved_searches/1.json
  def destroy
    @saved_search.destroy
    add_archived_at_header(@saved_search)
    respond_destroy
  end

  # POST /saved_searches/filter.json
  # GET /saved_searches/filter.json
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

  def saved_search_params
    # can't permit arbitrary hash
    # https://github.com/rails/rails/issues/9454#issuecomment-14167664
    # add arbitrary hash for stored_query manually
    params.require(:saved_search).permit(:id, :name, :description).tap do |allowed_params|
      if params[:saved_search][:stored_query]
        allowed_params[:stored_query] = params[:saved_search][:stored_query]
      end
    end
  end

  def get_saved_searches
    Access::Query.saved_searches(current_user, Access::Core.levels_allow)
  end

end
