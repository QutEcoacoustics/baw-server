class DatasetItemsController < ApplicationController

  include Api::ControllerHelper

  # GET /datasets/:dataset_id/items
  def index
    do_authorize_class
    get_dataset

    @dataset_items, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.dataset_items(current_user, @dataset),
        DatasetItem,
        DatasetItem.filter_settings
    )
    respond_index(opts)
  end

  # GET /datasets/:dataset_id/items/:dataset_item_id
  def show
    do_load_resource
    get_dataset
    do_authorize_instance
    respond_show
  end

  # GET|POST /dataset_items/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.dataset_items(current_user, nil),
        DatasetItem,
        DatasetItem.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  # GET /datasets/:dataset_id/items/new
  def new
    do_new_resource
    get_dataset
    do_set_attributes
    do_authorize_instance

    respond_show
  end

  # POST /datasets/:dataset_id/items
  def create
    do_new_resource
    do_set_attributes(dataset_item_params)
    get_dataset
    get_audio_recording

    # only admins can create
    do_authorize_instance

    if @dataset_item.save
      respond_create_success(dataset_item_path(@dataset, @dataset_item))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /datasets/:dataset_id/items/:dataset_item_id
  def update
    do_load_resource
    do_set_attributes(dataset_item_params)
    get_dataset
    do_authorize_instance

    respond_to do |format|
      if @dataset_item.update_attributes(dataset_item_params)
        format.json { respond_show }
      else
        format.json { respond_change_fail }
      end
    end
  end

  # DELETE /datasets/:dataset_id/items/:dataset_item_id
  def destroy
    do_load_resource
    get_dataset
    do_authorize_instance

    @dataset_item.destroy
    add_archived_at_header(@dataset_item)

    respond_destroy

  end

  private

  def dataset_item_params
    params.require(:dataset_item).permit(:audio_recording_id,
                                         :start_time_seconds,
                                         :end_time_seconds,
                                         :order)
  end

  def get_dataset
    @dataset = Dataset.find(params[:dataset_id])
    if defined?(@dataset_item) && @dataset_item.dataset.blank?
      @dataset_item.dataset = @dataset
    end
  end

  def get_audio_recording
    if defined?(@dataset_item) && @dataset_item.audio_recording.blank?
      @audio_recording = AudioRecording.find(params[:audio_recording_id])
      @dataset_item.audio_recording = @audio_recording
    end
  end

end
