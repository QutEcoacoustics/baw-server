# frozen_string_literal: true

class SitesController < ApplicationController
  include Api::ControllerHelper

  # GET /projects/:project_id/sites
  def index
    do_authorize_class
    get_project
    do_authorize_instance(:show, @project)

    respond_to do |format|
      #format.html # index.html.erb
      format.json {
        @sites, opts = Settings.api_response.response_advanced(
          api_filter_params,
          Access::ByPermission.sites(current_user, Access::Core.levels, [@project.id]),
          Site,
          Site.filter_settings
        )
        respond_index(opts)
      }
    end
  end

  # GET /sites/:id
  def show_shallow
    do_load_resource
    do_authorize_instance

    respond_to do |format|
      format.json { respond_show }
    end
  end

  # GET /projects/:project_id/sites/:id
  def show
    do_load_resource
    get_project
    do_authorize_instance

    respond_to do |format|
      format.html do @site.update_location_obfuscated(current_user) end
      format.json { respond_show }
    end
  end

  # GET /projects/:project_id/sites/new
  def new
    do_new_resource
    get_project
    do_set_attributes
    do_authorize_instance

    # initialize lat/lng to Brisbane-ish
    @site.longitude = 152
    @site.latitude = -27
    respond_to do |format|
      format.html
      format.json { respond_show }
    end
  end

  # GET /projects/:project_id/sites/:id/edit
  def edit
    do_load_resource
    get_project
    do_authorize_instance
  end

  # POST /projects/:project_id/sites
  def create
    do_new_resource
    do_set_attributes(site_params)
    get_project
    do_authorize_instance

    respond_to do |format|
      if @site.save
        format.html do redirect_to [@project, @site], notice: 'Site was successfully created.' end
        format.json { respond_create_success(project_site_path(@project, @site)) }
      else
        format.html do render action: 'new' end
        format.json { respond_change_fail }
      end
    end
  end

  # PUT|PATCH /projects/:project_id/sites/:id
  def update
    do_load_resource
    get_project
    do_authorize_instance

    @original_site_name = @site.name

    respond_to do |format|
      if @site.update_attributes(site_params)
        format.html do redirect_to [@project, @site], notice: 'Site was successfully updated.' end
        format.json { respond_show }
      else
        format.html do

          render action: 'edit'
        end
        format.json { respond_change_fail }
      end
    end
  end

  # DELETE /projects/:project_id/sites/:id
  def destroy
    do_load_resource
    get_project
    do_authorize_instance

    @site.destroy
    add_archived_at_header(@site)

    respond_to do |format|
      format.html do redirect_to project_sites_url(@project) end
      format.json { respond_destroy }
    end
  end

  # GET /projects/:project_id/sites/:id/upload_instructions
  def upload_instructions
    do_load_resource
    get_project
    do_authorize_instance

    respond_to do |format|
      format.html
    end
  end

  # GET /projects/:project_id/sites/:id/harvest
  def harvest
    do_load_resource
    get_project
    do_authorize_instance

    respond_to do |format|
      format.yml {
        render file: 'sites/_harvest.yml.haml', content_type: 'text/yaml', layout: false
      }
    end
  end

  # GET /sites/orphans
  def orphans
    do_authorize_class

    @sites = Site.find_by_sql('SELECT * FROM sites s WHERE s.id NOT IN (SELECT site_id FROM projects_sites) ORDER BY s.name')

    respond_to do |format|
      format.html
    end
  end

  # GET|POST /sites/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Access::ByPermission.sites(current_user),
      Site,
      Site.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  def nav_menu
    {
      anchor_after: 'baw.shared.links.projects.title',
      menu_items: [
        {
          title: 'baw.shared.links.projects.title',
          href: project_path(@project),
          tooltip: 'baw.shared.links.projects.description',
          icon: nil,
          indentation: 1
          #predicate:
        },
        {
          title: 'baw.shared.links.site.title',
          href: project_site_path(@project, @site),
          tooltip: 'baw.shared.links.site.description',
          icon: nil,
          indentation: 2
          #predicate:
        }
        # {
        #     title: 'baw.shared.links.ethics_statement.title',
        #     href: ethics_statement_path,
        #     tooltip: 'baw.shared.links.ethics_statement.description',
        #     icon: nil,
        #     indentation: 0,
        #     predicate: lambda { |user| action_name == 'ethics_statement' }
        # }
      ]
    }
  end

  private

  def get_project
    @project = Project.find(params[:project_id])

    # avoid the same project assigned more than once to a site
    @site.projects << @project if defined?(@site) && !@site.projects.include?(@project)
  end

  def site_params
    params.require(:site).permit(:name, :latitude, :longitude, :description, :image, :notes, :tzinfo_tz)
  end

  def site_show_params
    params.permit(:id, :project_id, site: {})
  end
end
