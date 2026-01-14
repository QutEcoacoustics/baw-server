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
      project_table = Project.arel_table
      ps_table = Arel::Table.new(:projects_sites)
      effective_permissions_table = Access::EffectivePermission::TABLE
      owner_sites_table = Arel::Table.new(:owner_sites)
      owner_level = ::Permission::LEVEL_TO_INTEGER_MAP[::Permission::OWNER]

      # Start building the main sites query
      # Join to region and projects
      base_sites_query = Site.all
        .joins(:region)
        .joins(
          site_table
            .join(ps_table)
            .on(site_table[:id].eq(ps_table[:site_id]))
            .join_sources
        )
        .joins(
          ps_table
            .join(project_table)
            .on(ps_table[:project_id].eq(project_table[:id]))
            .join_sources
        )

      # Add effective permissions CTE (calculates max permission level per project)
      # This adds the CTE and joins it to projects via LEFT OUTER JOIN
      # This replaces Access::ByPermission.sites which would create a second permissions join
      base_sites_query = Access::EffectivePermission.add_effective_permissions_cte(
        base_sites_query,
        current_user,
        project_table:
      )

      # Filter by permission level: user must have at least reader access
      permission_filter = Access::EffectivePermission.build_level_predicate(:reader)
      base_sites_query = base_sites_query.where(permission_filter)

      # For location obfuscation, we need to determine if user is an owner of ANY project
      # containing the site. We use a LEFT OUTER JOIN to a derived table of owner sites.
      # The effective_permissions CTE is already available and can be referenced in this subquery.
      
      # Build the owner sites subquery using Arel for safety
      ps_inner = Arel::Table.new(:projects_sites, as: 'ps_inner')
      p_inner = Arel::Table.new(:projects, as: 'p_inner')
      ep_inner = Arel::Table.new(:effective_permissions, as: 'ep_inner')
      
      owner_sites_subquery = ps_inner
        .project(ps_inner[:site_id].as('id'))
        .join(p_inner)
        .on(ps_inner[:project_id].eq(p_inner[:id]))
        .join(ep_inner, Arel::Nodes::OuterJoin)
        .on(p_inner[:id].eq(ep_inner[:project_id]))
        .where(
          ep_inner[:effective_level].coalesce(::Permission::LEVEL_TO_INTEGER_MAP[::Permission::NONE]).gteq(owner_level)
        )
        .distinct
      
      base_sites_query = base_sites_query
        .joins(
          site_table
            .join(owner_sites_subquery.as(owner_sites_table.name), Arel::Nodes::OuterJoin)
            .on(site_table[:id].eq(owner_sites_table[:id]))
            .join_sources
        )
        .distinct

      parent = Group.new(
        model: Site,
        base_query: base_sites_query,
        projections: {
          site_id: site_table[:id],
          region_id: region_table[:id],
          project_ids: Arel.grouping(Site.project_ids_arel),
          latitude: Site.visible_latitude_arel(current_user, site_table:, owner_table_alias: owner_sites_table),
          longitude: Site.visible_longitude_arel(current_user, site_table:, owner_table_alias: owner_sites_table),
          location_obfuscated: Site.location_obfuscated_arel(current_user, site_table:,
            owner_table_alias: owner_sites_table)
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
