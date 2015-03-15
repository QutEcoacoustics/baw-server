class BookmarksController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource

  def index
    @bookmarks, constructed_options = Settings.api_response.response_index(
        api_filter_params,
        Access::Query.bookmarks_modified(current_user),
        Bookmark,
        Bookmark.filter_settings
    )
    respond_index(constructed_options)
  end

  def show
    respond_show
  end

  def new
    respond_show
  end

  def create
    if @bookmark.save
      respond_create_success
    else
      respond_change_fail
    end
  end

  def update
    if @bookmark.update_attributes(bookmark_params)
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
        api_filter_params,
        Access::Query.bookmarks_modified(current_user),
        Bookmark,
        Bookmark.filter_settings
    )
    render_api_response(filter_response)
  end

  private

  def bookmark_params
    params.require(:bookmark).permit(:audio_recording_id, :name, :description, :offset_seconds, :category)
  end

end
