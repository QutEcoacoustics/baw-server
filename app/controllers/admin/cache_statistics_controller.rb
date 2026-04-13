# frozen_string_literal: true

module Admin
  # Admin-only controller to view media cache statistics.
  class CacheStatisticsController < Admin::BaseController
    include Api::ControllerHelper

    # GET /admin/cache_statistics
    def index
      do_authorize_class

      @cache_statistics, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Statistics::CacheStatistics.all,
        Statistics::CacheStatistics,
        Statistics::CacheStatistics.filter_settings
      )
      respond_index(opts)
    end

    # GET /admin/cache_statistics/:id
    def show
      do_load_resource
      do_authorize_instance

      respond_show
    end

    # GET|POST /admin/cache_statistics/filter
    def filter
      do_authorize_class

      filter_response, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Statistics::CacheStatistics.all,
        Statistics::CacheStatistics,
        Statistics::CacheStatistics.filter_settings
      )
      respond_filter(filter_response, opts)
    end
  end
end
