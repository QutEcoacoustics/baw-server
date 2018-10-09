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

  # POST /progress_events/items
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

  # POST /datasets/:dataset_id/progress_events/audio_recordings/:audio_recording_id/start/:start_time_seconds/end/:end_time_seconds
  # create a progress event without specifying a dataset item id by specifying the datset, audio_recording and offsets
  # will create an item in the default dataset if it does not exist
  def create_by_dataset_item_params

    # find dataset_item

    dataset_item_params = {
        dataset_id: params[:dataset_id].to_i,
        audio_recording_id: params[:audio_recording_id],
        start_time_seconds: params[:start_time_seconds],
        end_time_seconds: params[:end_time_seconds]
    }

    dataset_item = DatasetItem.find_by(dataset_item_params)

    resource_params = progress_event_params
    if dataset_item
      resource_params[:dataset_item_id] = dataset_item.id
    elsif dataset_item_params[:dataset_id].to_i == 1

      # is for the default dataset, so create the dataset item
      dataset_item = DatasetItem.new(dataset_item_params)
      do_authorize_instance :create, dataset_item

      if !dataset_item.save
        fail CustomErrors::UnprocessableEntityError.new(
            'Can not add progress event. Dataset item parameters were invalid.',
            dataset_item.errors.messages
        )
      end

      resource_params[:dataset_item_id] = dataset_item.id

    else
      fail CustomErrors::UnprocessableEntityError.new(
          'Can not add progress event. Dataset item not found.',
          dataset_item_params
      )
    end

    do_new_resource
    do_set_attributes(resource_params)
    do_authorize_instance :create

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
