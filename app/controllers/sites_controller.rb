class SitesController < ApplicationController
  include Api::ControllerHelper

  # order matters for before_action and load_and_authorize_resource!
  load_and_authorize_resource :project, except: [:show_shallow, :filter, :orphans]

  # this is necessary so that the ability has access to site.projects
  before_action :build_project_site, only: [:new, :create]

  load_and_authorize_resource :site, through: :project, except: [:show_shallow, :filter, :orphans]
  load_and_authorize_resource :site, only: [:show_shallow, :filter, :orphans]

  # GET /project/1/sites
  # GET /project/1/sites.json
  def index
    @sites = @project.sites

    respond_to do |format|
      #format.html # index.html.erb
      format.json {
        @sites, opts = Settings.api_response.response_advanced(
            api_filter_params,
            get_user_sites.where(projects: {id: @project.id}),
            Site,
            Site.filter_settings
        )
        respond_index(opts)
      }
    end
  end

  # GET /sites/1.json
  def show_shallow
    # only responds to json requests
    respond_to do |format|
      format.json { respond_show }
    end
  end

  # GET /project/1/sites/1
  # GET /project/1/sites/1.json
  def show
    respond_to do |format|
      format.html {
        @site.update_location_obfuscated(current_user)
      }
      format.json { respond_show }
    end
  end

  # GET /project/1/sites/new
  # GET /project/1/sites/new.json
  def new
    # required due to before_action building model, which causes cancan to assume already authorised
    do_authorize!

    @site.longitude = 152
    @site.latitude = -27
    respond_to do |format|
      format.html {
        @markers = @site.to_gmaps4rails do |site, marker|
          marker.infowindow 'Drag&Drop to site location. Delete Latitude and Longitude to specify no location.'
        end
      }
      format.json { respond_show }
    end
  end

  # GET /project/1/sites/1/edit
  def edit
    @markers = @site.to_gmaps4rails do |site, marker|
      marker.infowindow 'Drag&Drop to site location'
    end
  end

  # POST /project/1/sites
  # POST /project/1/sites.json
  def create
    # required due to before_action building model, which causes cancan to assume already authorised
    attributes_and_authorize(site_params)

    respond_to do |format|
      if @site.save
        format.html { redirect_to [@project, @site], notice: 'Site was successfully created.' }
        format.json { respond_create_success([@project, @site]) }
      else
        format.html {
          @markers = @site.to_gmaps4rails do |site, marker|
            marker.infowindow 'Drag&Drop to site location'
          end
          render action: 'new'
        }
        format.json { respond_change_fail }
      end
    end
  end

  # PUT /project/1/sites/1
  # PUT /project/1/sites/1.json
  def update
    @site.projects << @project unless @site.projects.include?(@project) # to avoid duplicates in the Projects_Sites table

    respond_to do |format|
      if @site.update_attributes(site_params)
        format.html { redirect_to [@project, @site], notice: 'Site was successfully updated.' }
        format.json { respond_show }
      else
        format.html {
          render action: 'edit'
        }
        format.json { respond_change_fail }
      end
    end
  end

  # DELETE /project/1/sites/1
  # DELETE /project/1/sites/1.json
  def destroy
    @site.destroy
    add_archived_at_header(@site)

    respond_to do |format|
      format.html { redirect_to project_sites_url(@project) }
      format.json { respond_destroy }
    end
  end

  def upload_instructions
    respond_to do |format|
      format.html
    end
  end

  def harvest
    render file: 'sites/_harvest.yml.erb', content_type: 'text/yaml', layout: false
  end

  # GET /sites/orphans
  def orphans
    @sites = Site.find_by_sql("SELECT * FROM sites s
WHERE s.id NOT IN (SELECT site_id FROM projects_sites)
ORDER BY s.name")

    respond_to do |format|
      format.html
    end

  end

  # POST /sites/filter.json
  # GET /sites/filter.json
  def filter
    authorize! :filter, Site
    filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_user_sites,
        Site,
        Site.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  private

  def build_project_site
    @site = Site.new
    @site.projects << @project
  end

  def get_user_sites
    Access::Query.sites(current_user, Access::Core.levels_allow).order('lower(sites.name) ASC')
  end

  def site_params
    params.require(:site).permit(:name, :latitude, :longitude, :description, :image, :notes, :tzinfo_tz)
  end

  def site_show_params
    params.permit(:id, :project_id, site: {})
  end

end
