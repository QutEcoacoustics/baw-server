class SavedSearchesController < ApplicationController
  add_breadcrumb 'Home', :root_path

  load_and_authorize_resource :project
  before_filter :build_project_saved_search, only: [:new, :create] # this is necessary so that the ability has access to site.projects
  load_and_authorize_resource :saved_search, through: :project

  before_filter :add_project_breadcrumb

  # GET /projects/:id/saved_searches
  # GET /projects/:id/saved_searches.json
  def index
    @saved_searches = @project.saved_searches

    respond_to do |format|
      #format.html # index.html.erb
      format.json { render json: @saved_searches }
    end
  end

  # GET /projects/:id/saved_searches/1
  # GET /projects/:id/saved_searches/1.json
  def show
    @saved_search = @project.saved_searches.find(params[:id])
    @preview_item = @saved_search.preview_results(AudioRecording.readonly).first

    respond_to do |format|
      format.html {
        add_breadcrumb @saved_search.name, [@project, @saved_search]
      }
      format.json { render json: @saved_search }
    end
  end

  # GET /projects/:id/saved_searches/new
  # GET /projects/:id/saved_searches/new.json
  def new
    @saved_search = SavedSearch.new

    respond_to do |format|
      format.html {
        add_breadcrumb 'New Dataset'
      }
      format.json { render json: @saved_search }
    end
  end

  # GET /projects/:id/saved_searches/1/edit
  def edit
    @saved_search = @project.saved_searches.find(params[:id])
    add_breadcrumb @saved_search.name, [@project, @saved_search]
    add_breadcrumb 'Edit'
  end

  # POST /projects/:id/saved_searches
  # POST /projects/:id/saved_searches.json
  def create
    @saved_search = SavedSearch.new(params[:saved_search])
    @saved_search.project = @project

    respond_to do |format|
      if @saved_search.save
        format.html { redirect_to [@project, @saved_search], notice: 'Dataset was successfully created.' }
        format.json { render json: @saved_search, status: :created, location: [@project, @saved_search] }
      else
        format.html { render action: "new" }
        format.json { render json: @saved_search.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /projects/:id/saved_searches/1
  # PUT /projects/:id/saved_searches/1.json
  def update
    @saved_search = SavedSearch.find(params[:id])
    respond_to do |format|
      if @saved_search.update_attributes(params[:saved_search])
        format.html { redirect_to [@project, @saved_search], notice: 'Dataset was successfully updated.' }
        format.json { head :no_content }
      else
        format.html {
          add_breadcrumb @saved_search.name, [@project, @saved_search]
          render action: "edit"
        }
        format.json { render json: @saved_search.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/:id/saved_searches/1
  # DELETE /projects/:id/saved_searches/1.json
  def destroy
    @saved_search = SavedSearch.find(params[:id])
    @saved_search.destroy

    respond_to do |format|
      format.html { redirect_to project_saved_search_url(@project) }
      format.json { head :no_content }
    end
  end

  private
  def add_project_breadcrumb
    add_breadcrumb 'Projects', projects_path
    add_breadcrumb @project.name, @project
  end

  def build_project_saved_search
    @saved_search = SavedSearch.new
    @saved_search.project = @project
  end
end
