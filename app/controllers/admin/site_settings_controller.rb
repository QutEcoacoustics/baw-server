# frozen_string_literal: true

module Admin
  # Database settings for the application. Dynamic.
  class SiteSettingsController < Admin::BaseController
    include Api::ControllerHelper

    # GET /admin/site_settings
    def index
      do_authorize_class

      set_resource_plural(Admin::SiteSetting.load_all_settings)
      respond_index
    end

    # GET /admin/site_settings/{setting_name}
    def show
      # customized find_resource, see below
      do_load_resource
      do_authorize_instance

      respond_show
    end

    # POST /admin/site_settings
    def create
      do_new_resource
      do_set_attributes(site_settings_params)
      do_authorize_instance
      if @site_setting.save
        respond_create_success
      else
        respond_change_fail
      end
    end

    # PUT|PATCH /admin/site_settings/{setting_name}
    def update
      do_load_resource
      do_set_attributes(site_settings_params)
      do_authorize_instance

      if @site_setting.save
        respond_show
      else
        respond_change_fail
      end
    end

    def create_or_update
      do_load_or_new_resource(site_settings_params, find_keys: [:name])
      do_authorize_instance

      return respond_change_fail unless @site_setting.save

      if @site_setting.previously_new_record?
        respond_create_success
      else
        respond_show
      end
    end

    # DELETE /admin/site_settings/{setting_name}
    # Handled in Archivable
    #

    private

    # override default find_resource so we can find by name or id
    def find_resource(query)
      id = id_param.to_i_strict

      if id
        query.find(id)
      else
        Admin::SiteSetting.load_setting(id_param)
      end
    end

    def site_settings_params
      permitted = params
        .require(:site_setting)
        .permit(
          :name,
          :value
        )

      # we also allow name to be specified in the route parameters
      permitted[:name] = params[:id] if params[:id] && !params[:id].to_i_strict

      permitted
    end
  end
end
