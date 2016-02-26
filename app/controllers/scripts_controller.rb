class ScriptsController < ApplicationController
  include Api::ControllerHelper

  # GET /scripts
  def index
    do_authorize_class

    respond_to do |format|
      format.json {
        @scripts, opts = Settings.api_response.response_advanced(
            api_filter_params,
            get_recent_scripts,
            Script,
            Script.filter_settings
        )
        respond_index(opts)
      }
    end
  end

  # GET /admin/scripts/:id
  def show
    do_load_resource
    do_authorize_instance

    respond_show
  end

  # GET|POST /scripts/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_scripts,
        Script,
        Script.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private


  def get_scripts
    Script.order(name: :asc).order(created_at: :desc)
  end

  def get_recent_scripts
    Script.all_most_recent_version
  end

end
