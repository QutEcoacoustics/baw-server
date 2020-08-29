# frozen_string_literal: true

class SitesController < ApplicationController
  include Api::ControllerHelper

  # GET /sites
  # GET /projects/:project_id/sites
  def index
    do_authorize_class
    get_project_if_exists
    do_authorize_instance(:show, @project) unless @project.nil?

    respond_to do |format|
      #format.html # index.html.erb
      format.json do
        @sites, opts = Settings.api_response.response_advanced(
          api_filter_params,
          list_permissions,
          Site,
          Site.filter_settings
        )
        respond_index(opts)
      end
    end
  end

  # GET /sites/:id
  # GET /projects/:project_id/sites/:id
  def show
    do_load_resource
    get_project_if_exists
    do_authorize_instance

    respond_to do |format|
      format.html { @site.update_location_obfuscated(current_user) }
      format.json { respond_show }
    end
  end

  # GET /sites/new
  # GET /projects/:project_id/sites/new
  def new
    do_new_resource
    get_project_if_exists
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

  # POST /sites
  # POST /projects/:project_id/sites
  def create
    do_new_resource
    do_set_attributes(site_params)
    get_project_if_exists
    do_authorize_instance

    respond_to do |format|
      if @site.save
        format.html { redirect_to [@project, @site], notice: 'Site was successfully created.' }
        format.json {
          if @project.nil?
            respond_create_success(shallow_site_path(@site))
          else
            respond_create_success(project_site_path(@project, @site))
          end
        }
      else
        format.html { render action: 'new' }
        format.json { respond_change_fail }
      end
    end
  end

  # PUT|PATCH /sites/:id
  # PUT|PATCH /projects/:project_id/sites/:id
  def update
    do_load_resource
    get_project_if_exists
    do_authorize_instance

    @original_site_name = @site.name

    respond_to do |format|
      if @site.update(site_params)
        format.html { redirect_to [@project, @site], notice: 'Site was successfully updated.' }
        format.json { respond_show }
      else
        format.html do
          render action: 'edit'
        end
        format.json { respond_change_fail }
      end
    end
  end

  # DELETE /sites/:id
  # DELETE /projects/:project_id/sites/:id
  def destroy
    do_load_resource
    get_project_if_exists
    do_authorize_instance

    @site.destroy
    add_archived_at_header(@site)

    respond_to do |format|
      format.html { redirect_to project_sites_url(@project) }
      format.json { respond_destroy }
    end
  end

  # GET /projects/:project_id/sites/:id/upload_instructions
  def upload_instructions
    do_load_resource
    get_project
    do_authorize_instance

    respond_to { |format| format.html }
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

  # GET|POST /sites/orphans{/filter}
  def orphans
    do_authorize_class

    @sites = Site.with_deleted.left_joins(:projects_sites).where('projects_sites.project_id IS NULL')

    respond_to { |format|
      format.html
      format.json {
        filter_response, opts = Settings.api_response.response_advanced(
          api_filter_params,
          @sites,
          Site,
          Site.filter_settings
        )
        respond_filter(filter_response, opts)
      }
    }
  end

  # GET|POST /sites/filter
  # GET|POST /projects/:project_id/sites/filter
  def filter
    do_authorize_class
    get_project_if_exists
    do_authorize_instance(:show, @project) unless @project.nil?

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      list_permissions,
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

  def get_project_if_exists
    return unless params.key?(:project_id)

    @project = Project.find(params[:project_id])
    # avoid the same project assigned more than once to a site
    @site.projects << @project if defined?(@site) && defined?(@project) && !@site.projects.include?(@project)
  end

  def list_permissions
    if @project.nil?
      Access::ByPermission.sites(current_user)
    else
      Access::ByPermission.sites(current_user, project_ids: [@project.id])
    end
  end

  def site_params
    params.require(:site).permit(:name, :latitude, :longitude, :description, :image, :notes, :tzinfo_tz, project_ids: [])
  end

  def site_show_params
    params.permit(:id, :project_id, site: {})
  end
end
