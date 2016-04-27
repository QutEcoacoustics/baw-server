module Admin
  class ScriptsController < BaseController

    # GET /admin/scripts
    def index
      respond_to do |format|
        format.html { @scripts = get_scripts}
      end
    end

    # GET /admin/scripts/:id
    def show
      @script = Script.find(params[:id])
      @all_script_versions = @script.all_versions

      respond_to do |format|
        format.html
      end
    end

    # GET /admin/scripts/new
    def new
      @script = Script.new
    end

    # GET /admin/scripts/:id/edit
    def edit
      @script = Script.find(params[:id])

      unless @script.is_last_version?
        redirect_to edit_admin_script_path(@script.latest_version), notice: 'You have been redirected to update the latest version of this Script.'
      end
    end

    # POST /admin/scripts
    def create
      @script = Script.new(script_params)

      respond_to do |format|
        if @script.save
          format.html { redirect_to admin_script_path(@script), notice: 'Script was successfully created.' }
          format.json { respond_create_success }
        else
          format.html { render action: 'new' }
          format.json { respond_change_fail }
        end
      end
    end

    # POST /admin/scripts/:id
    def update
      @script = Script.find(params[:id])

      unless @script.is_last_version?
        respond_to do |format|
          format.html { redirect_to edit_admin_script_path(@script.latest_version), notice: 'You have been redirected to update the latest version of this Script.' }
          format.json { respond_change_fail }
        end
      end

      new_script_params = script_params

      @new_script = Script.new(new_script_params)

      @new_script.group_id = @script.group_id

      respond_to do |format|
        if @new_script.save && @script.save
          format.html { redirect_to admin_script_path(@new_script), notice: 'A new version of the Script was successfully created.' }
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

    def destroy
      redirect_to edit_admin_script_path(@script.latest_version), notice: 'Create a new script version rather than deleting a script.'
    end

    private

    def script_params
      params.require(:script).permit(
          :name, :description, :analysis_identifier,
          :version, :verified,
          :executable_command,
          :executable_settings, :executable_settings_media_type)
    end

    def get_scripts
      Script.order(name: :asc).order(created_at: :desc)
    end
  end
end