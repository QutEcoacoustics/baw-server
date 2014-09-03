class BookmarksController < ApplicationController
  include Api::ControllerHelper

  add_breadcrumb 'Home', :root_path

  load_and_authorize_resource
  respond_to :json

  def index
    @bookmarks, constructed_options = Settings.api_response.response_index(
        params,
        current_user.accessible_bookmarks,
        Bookmark,
        Bookmark.filter_settings
    )
    respond_index
  end

  def show
    respond_show
  end

  def new
    respond_to do |format|
      format.html {
        add_breadcrumb 'Bookmarks', bookmarks_path
        add_breadcrumb @bookmark.name, @bookmark
      }
      format.json { respond_show }
    end
  end

  def create
    if @bookmark.save
      respond_create_success
    else
      respond_change_fail
    end
  end

  def update
    if @bookmark.update_attributes(params[:bookmark])
      respond_show
    else
      respond_change_fail
    end
  end

  def destroy
    @bookmark.destroy
    respond_destroy
  end

  def filter
    filter_response = Settings.api_response.response_filter(
        params,
        current_user.accessible_bookmarks,
        Bookmark,
        Bookmark.filter_settings
    )
    render_api_response(filter_response)
  end

end
