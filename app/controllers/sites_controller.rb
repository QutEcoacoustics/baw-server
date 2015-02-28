class SitesController < ApplicationController
  include Api::ControllerHelper

  add_breadcrumb 'Home', :root_path

  # order matters for before_action and load_and_authorize_resource!
  load_and_authorize_resource :project, except: [:show_shallow, :filter]

  # this is necessary so that the ability has access to site.projects
  before_action :build_project_site, only: [:new, :create]

  load_and_authorize_resource :site, through: :project, except: [:show_shallow, :filter]
  load_and_authorize_resource :site, only: [:show_shallow, :filter]

  before_action :add_project_breadcrumb, except: [:show_shallow, :filter]

  # GET /project/1/sites
  # GET /project/1/sites.json
  def index
    @sites = @project.sites

    respond_to do |format|
      #format.html # index.html.erb
      format.json {
        @sites, constructed_options = Settings.api_response.response_index(
            api_filter_params,
            get_user_sites,
            Site,
            Site.filter_settings
        )
        respond_index
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
    @site_audio_recordings = @site
                                 .audio_recordings
                                 .where(status: 'ready')
                                 .order('recorded_date DESC')
                                 .paginate(page: params[:page], per_page: 30)

    respond_to do |format|
      format.html {
        @site.update_location_obfuscated(current_user)
        add_breadcrumb @site.name, [@project, @site]
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
        add_breadcrumb 'New Site'
      }
      format.json { respond_show }
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
    # required due to before_action building model, which causes cancan to assume already authorised
    attributes_and_authorize(site_params)

    respond_to do |format|
      if @site.save
        format.html { redirect_to [@project, @site], notice: 'Site was successfully created.' }
        format.json { respond_create_success([@project, @site]) }
      else
        format.html {
          add_breadcrumb @site.name, [@project, @site]
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
          add_breadcrumb @site.name, [@project, @site]
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
        api_filter_params,
        get_user_sites,
        Site,
        Site.filter_settings
    )

    # include custom response components
    filter_response[:data] = filter_response[:data].map { |site|
      respond_modify(site)
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

  def api_custom_response(site)
    # TODO: does this needs to know about and change based on projections?

    site.update_location_obfuscated(current_user)

    site_hash = {}

    site_hash[:project_ids] = Site.where(id: site.id).first.projects.pluck(:id)
    site_hash[:location_obfuscated] = site.location_obfuscated
    site_hash[:custom_latitude] = site.latitude
    site_hash[:custom_longitude] = site.longitude

    [site, site_hash]
  end

  def get_user_sites
    if current_user.has_role? :admin
      sites = Site.includes(:creator).order('lower(name) ASC')
    else
      sites = current_user.accessible_sites
    end

    sites
  end

  def site_params
    params.require(:site).permit(:name, :latitude, :longitude, :description, :image, :notes)
  end

  def site_show_params
    params.permit(:id, :project_id, site: {})
  end

end
