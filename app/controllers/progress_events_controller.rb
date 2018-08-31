class ProgressEventsController < ApplicationController

  include Api::ControllerHelper

  # GET /progress_events
  def index
    do_authorize_class

    @progress_events, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.progress_events(current_user, params[:dataset_item_id]),
        ProgressEvent,
        ProgressEvent.filter_settings
    )

    respond_index(opts)
  end

  # GET /progress_events/:progress_event_id
  def show
    do_load_resource
    do_authorize_instance
    respond_show
  end

  # GET|POST /progress_events/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.progress_events(current_user, params[:dataset_item_id]),
        ProgressEvent,
        ProgressEvent.filter_settings
    )

    respond_filter(filter_response, opts)
  end

  # GET /progress_events/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance
    respond_show
  end

  # POST /progress_events
  def create

    do_new_resource
    do_set_attributes(progress_event_params)
    do_authorize_instance

    if @progress_event.save
      respond_create_success(progress_event_path(@progress_event))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /progress_events/:progress_event_id
  def update

    do_load_resource
    do_set_attributes(progress_event_params)
    do_authorize_instance

    if @progress_event.update_attributes(progress_event_params)
      respond_show
    else
      respond_change_fail
    end

  end

  # DELETE /progress_events/:progress_event_id
  def destroy

    do_load_resource
    do_authorize_instance
    @progress_event.destroy
    respond_destroy

  end

  private

  def progress_event_params

    params.require(:progress_event).permit(:dataset_item_id, :activity)

  end

end
