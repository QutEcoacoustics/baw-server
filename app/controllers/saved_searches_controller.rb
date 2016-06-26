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

    respond_show
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
  def destroy
    do_load_resource
    do_authorize_instance

    @saved_search.destroy
    add_archived_at_header(@saved_search)
    respond_destroy
  end

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
    Access::ByPermission.saved_searches(current_user)
  end

end
