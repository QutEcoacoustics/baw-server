class ScriptsController < ApplicationController
  include Api::ControllerHelper

  # GET /scripts
  def index
    do_authorize_class

    respond_to do |format|
      format.html { @scripts = get_scripts}
      format.json {
        @scripts, opts = Settings.api_response.response_advanced(
            api_filter_params,
            get_scripts,
            Script,
            Script.filter_settings
        )
        respond_index(opts)
      }
    end
  end

  # GET /scripts/:id
  def show
    do_load_resource
    do_authorize_instance

    @all_script_versions = @script.all_versions

    respond_to do |format|
      format.html
      format.json { respond_show }
    end
  end


  # GET /scripts/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance

    respond_to do |format|
      format.html
      format.json { respond_show }
    end
  end

  # GET /scripts/:id/edit
  def edit
    do_load_resource
    do_authorize_instance

    unless @script.is_latest_version?
      redirect_to edit_script_path(@script.latest_version), notice: 'You have been redirected to update the latest version of this Script.'
    end
  end

  # POST /scripts
  def create
    do_new_resource
    do_set_attributes(script_params)
    do_authorize_instance

    respond_to do |format|
      if @script.save
        format.html { redirect_to @script, notice: 'Script was successfully created.' }
        format.json { respond_create_success }
      else
        format.html { render action: 'new' }
        format.json { respond_change_fail }
      end
    end
  end

  # POST /scripts/:id
  def update
    do_load_resource
    do_authorize_instance

    unless @script.is_latest_version?
      respond_to do |format|
        format.html { redirect_to edit_script_path(@script.latest_version), notice: 'You have been redirected to update the latest version of this Script.' }
        format.json { respond_change_fail }
      end
    end

    new_script_params = script_params

    @new_script = Script.new(new_script_params)

    @new_script.group_id = @script.group_id

    respond_to do |format|
      if @new_script.save && @script.save
        format.html { redirect_to @new_script, notice: 'A new version of the Script was successfully created.' }
        format.json { respond_show }
      else
        format.html {
          @old_script = @script
          @script = @new_script # so that it renders the errors
          render action: 'update'
        }
        format.json { respond_change_fail }
      end
    end
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

  def script_params
    params.require(:script).permit(
        :name, :description, :analysis_identifier,
        :version, :verified,
        :executable_command, :executable_settings)
  end

  def get_scripts
    Script.order(name: :asc).order(created_at: :desc)
  end

end
