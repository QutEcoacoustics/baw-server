# frozen_string_literal: true

module Sites
  # Controller for returning audio events grouped by site
  class GroupByController < ApplicationController
    include Api::ControllerHelper
    include Api::GroupBy

    # GET | POST /sites/group_by/audio_events
    # Returns a list of sites with a count of audio events for each site.
    # Accepts filter object where:
    #   the `filter` is applied to audio events
    #   the `paging`, `sort` and `projection` options are invalid
    def group_sites_by_audio_events
      do_authorize_group_classes(Site, AudioEvent)

      site_table = Site.arel_table
      region_table = Region.arel_table

      parent = Group.new(
        model: Site,
        base_query:
          # TODO: it would be better if we could role the effective permissions query
          # and the by permission query into one to avoid double joining the permissions table
          Access::EffectivePermission.add_effective_permissions_cte(
            Access::ByPermission.sites(current_user),
            current_user
          )
          .joins(:region),
        projections: {
          site_id: site_table[:id],
          region_id: region_table[:id],
          project_ids: Arel.grouping(Site.project_ids_arel),
          latitude: Site.visible_latitude_arel(Current.user, site_table:, owner_table_alias: owner_sites_alias),
          longitude: Site.visible_longitude_arel(Current.user, site_table:, owner_table_alias: owner_sites_alias),
          location_obfuscated: Site.location_obfuscated_arel(Current.user, site_table:,
            owner_table_alias: owner_sites_alias)
        }
      )

      child = Group.new(
        model: AudioEvent,
        base_query: Access::ByPermission.audio_events(current_user),
        projections: {
          audio_event_count: AudioEvent.arel_table[:id].count
        }
      )

      result, opts = do_group_by_query(
        parent:,
        child:,
        filter_settings: AudioEvent.filter_settings,
        joins: { audio_recording: :site }
      )

      respond_group_by(result, opts)
    end
  end
end
