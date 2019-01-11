class DatasetItemsController < ApplicationController

  include Api::ControllerHelper

  # GET /datasets/:dataset_id/items
  def index
    do_authorize_class

    @dataset_items, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.dataset_items(current_user, params[:dataset_id]),
        DatasetItem,
        DatasetItem.filter_settings
    )

    respond_index(opts)
  end

  # GET /datasets/:dataset_id/items/:dataset_item_id
  def show
    do_load_resource
    do_authorize_instance
    respond_show
  end

  # GET|POST /dataset_items/filter
  # GET|POST datasets/:dataset_id/dataset_items/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.dataset_items(current_user, params[:dataset_id]),
        DatasetItem,
        DatasetItem.filter_settings(:reverse_order)
    )

    respond_filter(filter_response, opts)
  end

  # GET datasets/:dataset_id/dataset_items/next_for_me
  def next_for_me

    do_authorize_class
    priority_algorithm = DatasetItem.next_for_user(current_user_id = current_user ? current_user.id : nil)

    # All dataset items that the user has permission to see
    query = Access::ByPermission.dataset_items(current_user, params[:dataset_id])

    # sort by priority
    query = query.order(priority_algorithm)

    query, opts = Settings.api_response.response_advanced(
        api_filter_params,
        query,
        DatasetItem,
        DatasetItem.filter_settings
    )

    respond_filter(query, opts)

  end

  # GET /datasets/:dataset_id/items/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_show
  end

  # POST /datasets/:dataset_id/items
  def create

    do_new_resource
    do_set_attributes(dataset_item_params)

    # only admins can create
    do_authorize_instance

    if @dataset_item.save
      respond_create_success(dataset_item_path(params[:dataset_id], @dataset_item))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /datasets/:dataset_id/items/:dataset_item_id
  def update
    do_load_resource
    do_set_attributes(dataset_item_params)
    do_authorize_instance

    if @dataset_item.update_attributes(dataset_item_params)
      respond_show
    else
      respond_change_fail
    end

  end

  # DELETE /datasets/:dataset_id/items/:dataset_item_id
  def destroy
    do_load_resource
    do_authorize_instance

    @dataset_item.destroy

    respond_destroy

  end

  private

  def dataset_item_params

    params[:dataset_item][:dataset_id] = params[:dataset_id]

    params.require(:dataset_item).permit(:dataset_id,
                                         :audio_recording_id,
                                         :start_time_seconds,
                                         :end_time_seconds,
                                         :order)

  end


end