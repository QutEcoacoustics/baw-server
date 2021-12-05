# frozen_string_literal: true

class BookmarksController < ApplicationController
  include Api::ControllerHelper

  # GET /bookmarks
  def index
    do_authorize_class

    @bookmarks, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByUserModified.bookmarks(current_user),
      Bookmark,
      Bookmark.filter_settings
    )
    respond_index(opts)
  end

  # GET /bookmarks/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /bookmarks/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /bookmarks
  def create
    do_new_resource
    do_set_attributes(bookmark_params)
    do_authorize_instance

    if @bookmark.save
      respond_create_success
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /bookmarks/:id
  def update
    do_load_resource
    do_authorize_instance

    if @bookmark.update(bookmark_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /bookmarks/:id
  def destroy
    do_load_resource
    do_authorize_instance

    @bookmark.destroy
    respond_destroy
  end

  # GET|POST /bookmarks/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByUserModified.bookmarks(current_user),
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
