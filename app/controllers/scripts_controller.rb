class ScriptsController < ApplicationController

  load_and_authorize_resource :script

  # GET /scripts
  # GET /scripts.json
  def index
    @scripts = Script.latest_versions

    respond_to do |format|
      format.html
      format.json { render json: @scripts }
    end
  end

  # GET /scripts/1
  # GET /scripts/1.json
  def show
    respond_to do |format|
      format.html
      format.json { render json: @script }
    end
  end


  # GET /scripts/new
  # GET /scripts/new.json
  def new
    respond_to do |format|
      format.html
      format.json { render json: @script }
    end
  end

  # GET /scripts/1/edit
  def edit
    unless @script.is_latest_version?
      redirect_to edit_script_path(@script.latest_version), notice: 'You have been redirected to update the latest version of this Script.'
    end
  end

  # POST /scripts
  # POST /scripts.json
  def create
    respond_to do |format|
      if @script.save
        format.html { redirect_to @script, notice: 'Script was successfully created.' }
        format.json { render json: @script, status: :created, location: @script }
      else
        format.html { render action: 'new' }
        format.json { render json: @script.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /scripts/1
  # POST /scripts/1.json
  def update
    unless @script.is_latest_version?
      respond_to do |format|
        format.html { redirect_to edit_script_path(@script.latest_version) , notice: 'You have been redirected to update the latest version of this Script.'}
        format.json { render json: @script, status: :unprocessable_entity }
      end
    end

    @new_script = Script.new(script_params)

    @new_script.update_from = @script

    respond_to do |format|
      if @new_script.save && @script.save
        format.html { redirect_to @new_script, notice: 'A new version of the Script was successfully created.' }
        format.json { head :no_content }
      else
        format.html {
          @old_script = @script
          @script = @new_script # so that it renders the errors
          render action: 'update'
        }
        format.json { render json: @script.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def script_params
    params.require(:script).permit(
        :analysis_identifier, :data_file, :description,
        :name, :notes, :settings_file, :verified, :version)
  end

end
