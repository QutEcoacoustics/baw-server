# frozen_string_literal: true

module AudioEvents
  # Controller for returning audio events grouped by parent resources (e.g., sites)
  class GroupByController < ApplicationController
    include Api::ControllerHelper
    include Api::GroupBy

    # GET | POST /audio_events/group_by/sites
    # Returns a list of sites with a count of audio events for each site.
    # Accepts filter object where:
    #   the `filter` is applied to audio events
    #   the `paging`, `sort` and `projection` options are invalid
    def group_audio_events_by_sites
      do_authorize_group_classes(Site, AudioEvent)

      parent = Group.new(
        model: Site,
        base_query: Access::ByPermissionTable
          .sites(current_user, level: Access::Permission::READER)
          # TODO: change back to #joins once we remove projects_sites
          .left_joins(:region),
        projections: {
          site_id: Site.arel_table[:id],
          region_id: Region.arel_table[:id],
          project_ids: Arel.grouping(Site.project_ids_arel),
          location_obfuscated: Site.should_return_obfuscated_location_arel,
          latitude: Site.latitude_arel,
          longitude: Site.longitude_arel
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

    private

    # Allow anonymous access - authorization is handled by do_authorize_group_classes
    def should_authenticate_user?
      false
    end
  end
end
