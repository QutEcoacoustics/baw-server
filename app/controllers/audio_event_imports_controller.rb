# frozen_string_literal: true

# Controller for audio event imports
class AudioEventImportsController < ApplicationController
  include Api::ControllerHelper

  # GET /audio_event_imports
  def index
    do_authorize_class

    @audio_event_imports, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      AudioEventImport,
      AudioEventImport.filter_settings
    )
    respond_index(opts)
  end

  # GET /audio_event_imports/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET /audio_event_imports/new
  def new
    do_new_resource

    do_set_attributes
    do_authorize_instance

    respond_new
  end

  # POST /audio_event_imports
  def create
    do_new_resource
    do_set_attributes(audio_event_import_params)
    do_authorize_instance

    @audio_event_import.save

    if @audio_event_import.save
      respond_create_success(audio_event_import_path(@audio_event_import))
    else
      respond_change_fail
    end
  end

  # PUT|PATCH /audio_event_imports/:id
  def update
    do_load_resource
    do_authorize_instance

    if @audio_event_import.update(audio_event_import_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # GET|POST /audio_event_imports/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
      AudioEventImport,
      AudioEventImport.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def list_permissions
    Access::ByUserModified.audio_event_imports(current_user)
  end

  def has_audio_event_import_params?
    params.key?(:audio_event_import)
  end

  def audio_event_import_params
    params
      .require(:audio_event_import)
      .permit(:name, :description)
  end
end
