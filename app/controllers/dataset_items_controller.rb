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
    #priority_algorithm = DatasetItem.next_for_user(current_user_id = current_user ? current_user.id : nil)

    # All dataset items that the user has permission to see
    query = Access::ByPermission.dataset_items(current_user, params[:dataset_id])

    query = query.joins("LEFT OUTER JOIN progress_events ON progress_events.dataset_item_id = dataset_items.id AND activity = 'viewed'")
    query = query.group('dataset_items.id')
    query = query.order('COUNT(progress_events.id) ASC')
    if (current_user)
      query = query.order('SUM (CASE WHEN ("progress_events"."creator_id" = ' + current_user.id.to_s + ') THEN 1 ELSE 0 END) ASC')
    end
    query = query.order('dataset_items.order ASC')
    query = query.order('dataset_items.id ASC')


    # sort by priority
    # query = query.order(priority_algorithm)

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

    if @dataset_item.update(dataset_item_params)
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
