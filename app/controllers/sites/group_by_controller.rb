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

      parent = Group.new(
        model: Site,
        base_query: Access::ByPermission.sites(current_user)
          .joins(:region)
          .joins(Arel.obfuscate_location(s[:latitude], s[:longitude], jitter_amount: 0.03, salt: s[:id])),
        projections: {
          site_id: Site.arel_table[:id],
          region_id: Region.arel_table[:id],
          project_ids: Arel.grouping(Site.project_ids_arel)
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
      debugger
      respond_group_by(result, opts)
    end
  end
end
