class BookmarksController < ApplicationController
  include Api::ControllerHelper

  load_and_authorize_resource

  def index
    @bookmarks, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::Query.bookmarks_modified(current_user),
        Bookmark,
        Bookmark.filter_settings
    )
    respond_index(opts)
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
    authorize! :filter, Bookmark
    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::Query.bookmarks_modified(current_user),
        Bookmark,
        Bookmark.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def bookmark_params
    params.require(:bookmark).permit(:audio_recording_id, :name, :description, :offset_seconds, :category)
  end

end
