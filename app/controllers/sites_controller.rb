class SitesController < ApplicationController
  include Api::ControllerHelper

  add_breadcrumb 'Home', :root_path

  # order matters for before_filter and load_and_authorize_resource!
  load_and_authorize_resource :project, except: [:show_shallow, :filter]

  # this is necessary so that the ability has access to site.projects
  before_filter :build_project_site, only: [:new, :create]

  load_and_authorize_resource :site, through: :project, except: [:show_shallow, :filter]
  load_and_authorize_resource :site, only: [:show_shallow, :filter]

  before_filter :add_project_breadcrumb, except: [:show_shallow, :filter]

  # GET /project/1/sites
  # GET /project/1/sites.json
  def index
    @sites = @project.sites

    respond_to do |format|
      #format.html # index.html.erb
      format.json { render json: @sites }
    end
  end

  # GET /sites/1.json
  def show_shallow

    @site.update_location_obfuscated(current_user)

    # only responds to json requests
    respond_to do |format|
      format.json { render json: @site, methods: [:project_ids, :location_obfuscated], except: :notes }
    end
  end

  # GET /project/1/sites/1
  # GET /project/1/sites/1.json
  def show
    @site_audio_recordings = @site.audio_recordings.where(status: 'ready').order('recorded_date DESC').paginate(page: params[:page], per_page: 30)

    @site.update_location_obfuscated(current_user)

    respond_to do |format|
      format.html {
        add_breadcrumb @site.name, [@project, @site]
      }
      format.json { render json: @site, methods: [:project_ids, :location_obfuscated], except: :notes }
    end
  end

  # GET /project/1/sites/new
  # GET /project/1/sites/new.json
  def new

    attributes_and_authorize

    @site.longitude = 152
    @site.latitude = -27
    respond_to do |format|
      format.html {
        @markers = @site.to_gmaps4rails do |site, marker|
          marker.infowindow 'Drag&Drop to site location. Delete Latitude and Longitude to specify no location.'
        end
        add_breadcrumb 'New Site'
      }
      format.json { render json: @site }
    end
  end

  # GET /project/1/sites/1/edit
  def edit
    add_breadcrumb @site.name, [@project, @site]
    add_breadcrumb 'Edit'
    @markers = @site.to_gmaps4rails do |site, marker|
      marker.infowindow 'Drag&Drop to site location'
    end
  end

  # POST /project/1/sites
  # POST /project/1/sites.json
  def create

    attributes_and_authorize

    respond_to do |format|
      if @site.save
        format.html { redirect_to [@project, @site], notice: 'Site was successfully created.' }
        format.json { render json: @site, status: :created, location: [@project, @site] }
      else
        format.html {
          add_breadcrumb @site.name, [@project, @site]
          @markers = @site.to_gmaps4rails do |site, marker|
            marker.infowindow 'Drag&Drop to site location'
          end
          render action: "new"
        }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /project/1/sites/1
  # PUT /project/1/sites/1.json
  def update
    @site.projects << @project unless @site.projects.include?(@project) # to avoid duplicates in the Projects_Sites table

    respond_to do |format|
      if @site.update_attributes(params[:site])
        format.html { redirect_to [@project, @site], notice: 'Site was successfully updated.' }
        format.json { head :no_content }
      else
        format.html {
          add_breadcrumb @site.name, [@project, @site]
          render action: "edit"
        }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /project/1/sites/1
  # DELETE /project/1/sites/1.json
  def destroy
    @site.destroy

    respond_to do |format|
      format.html { redirect_to project_sites_url(@project) }
      format.json { head :no_content }
    end
  end

  def upload_instructions
    respond_to do |format|
      format.html {
        add_breadcrumb @site.name, [@project, @site]
        add_breadcrumb 'Upload Instructions'
      }
    end
  end

  def harvest
    render file: 'sites/_harvest.yml.erb', content_type: 'text/yaml', layout: false
  end

  # POST /sites/filter.json
  # GET /sites/filter.json
  def filter
    filter_response = Settings.api_response.response_filter(
        params,
        current_user.is_admin? ? Site.scoped : current_user.accessible_sites,
        Site,
        Site.filter_settings
    )

    # always get project_ids
    # allow project_ids
    filter_response[:data] = filter_response.data.each { |site|
      site[:project_ids] = Site.where(id: site.id).first.projects.select(:id)
      site
    }

    render_api_response(filter_response)
  end

  private
  def add_project_breadcrumb
    add_breadcrumb 'Projects', projects_path
    add_breadcrumb @project.name, @project
  end

  def build_project_site
    @site = Site.new
    @site.projects << @project
  end
end
