module Access
  class Apply
    class << self

      # Add project access restrictions from permissions and other sources.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @param [ActiveRecord::Relation] query
      # @return [ActiveRecord::Relation] modified query
      def restrictions(user, levels, query)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        # see http://jpospisil.com/2014/06/16/the-definitive-guide-to-arel-the-sql-manager-for-ruby.html

        # .includes eager loads tables using left outer join
        # .references ensures the join is added to the sql when using sql string fragments
        # .joins uses inner join
        # need to use left outer join for permissions, as there might not be a permission, but the project
        # should be included because the user created it

        # .includes eager loads
        # @see http://stackoverflow.com/questions/24397640/rails-nested-includes-on-active-records
        # Note that includes works with association names while references needs the actual table name.
        # @see http://api.rubyonrails.org/classes/ActiveRecord/QueryMethods.html#method-i-includes

        if Access::Check.is_admin?(user)
          intersection = Access::Core.levels_deny & levels
          if intersection.empty?
            # admin users have full access to everything at any level
            query
          else
            # since admin can access everything, any deny level returns nothing
            query.none
          end

        elsif Access::Check.is_standard_user?(user)
          model_name = query.model.model_name.name
          if model_name == 'Project'
            project_restrictions(user, levels, query)
          elsif %w(Site AudioRecording Bookmark AudioEvent AudioEventComment Tagging).include?(model_name)
            site_restrictions(user, levels, query)
          elsif %w(SavedSearch AnalysisJob).include?(model_name)
            saved_search_restrictions(user, levels, query)
          # elsif %w(Tagging).include?(model_name)
          #   audio_event_restriction(user, levels, query)
          else
            fail NotImplementedError, "Restrictions are not implemented for #{model_name}."
          end

        else
          restrictions_none(user, query)

        end

      end

      # Restrict access by joining on sites (one to many)
      # Access is allowed if there are *any* matches
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @param [ActiveRecord::Relation] query
      # @return [ActiveRecord::Relation]
      def site_restrictions(user, levels, query)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        pt = Project.arel_table
        pm = Permission.arel_table
        ps = Arel::Table.new(:projects_sites)
        si = Site.arel_table
        user_id = user.id
        exists, levels = Access::Apply.permission_levels(levels)

=begin
SELECT *
FROM sites
WHERE
    EXISTS
        (SELECT 1
        FROM projects_sites
        WHERE
            "sites"."id" = "projects_sites"."site_id"
            AND EXISTS (
                (SELECT 1
                FROM "projects"
                WHERE
                    "projects"."deleted_at" IS NULL
                    AND "projects"."creator_id" = 7
                    AND "projects_sites"."project_id" = "projects"."id"
                )
                UNION ALL
                (SELECT 1
                FROM "permissions"
                WHERE
                    "permissions"."user_id" = 7
                    AND "permissions"."level" IN ('reader', 'writer', 'owner')
                    AND "projects_sites"."project_id" = "permissions"."project_id"
                )
            )
        )
OR
    EXISTS
        (SELECT 1
        FROM "audio_events" ae1
        WHERE
            ae1."deleted_at" IS NULL
            AND ae1."is_reference" = TRUE
            AND "audio_events"."id" = ae1.id
        )
=end

        # after adding logged_in and anonymous permissions.
        # query
        #     .where(
        #         '(NOT EXISTS (SELECT 1 FROM permissions invert_pm_logged_in WHERE invert_pm_logged_in.logged_in = TRUE AND invert_pm_logged_in.project_id = projects.id))')
        #     .where(
        #         '(NOT EXISTS (SELECT 1 FROM permissions invert_pm WHERE invert_pm.user_id = ? AND invert_pm.project_id = projects.id))',
        #         user.id)

        # after adding logged_in and anonymous permissions.
        # permissions_user_fragment = Permission.where(user: user, level: levels, logged_in: false, anonymous: false).select(:project_id)
        # permissions_logged_in_fragment = Permission.where(user: nil, level: levels, logged_in: true, anonymous: false).select(:project_id)
        # condition_pt = pt[:id].in(permissions_logged_in_fragment.arel).or(pt[:id].in(permissions_user_fragment.arel))

        # need to add the 'deleted_at IS NULL' check by hand

        project_creator =
            pt
                .where(pt[:deleted_at].eq(nil))
                .where(pt[:creator_id].eq(user_id))
                .where(ps[:project_id].eq(pt[:id]))
                .project(1)

        project_permissions =
            pm
                .where(pm[:user_id].eq(user_id))
                .where(pm[:level].in(levels))
                .where(ps[:project_id].eq(pm[:project_id]))
                .project(1)

        union_all_projects =
            project_creator
                .union(:all, project_permissions)

        projects_exists = Arel::Nodes::Exists.new(union_all_projects)

        sites_exist =
            ps
                .where(si[:id].eq(ps[:site_id]))
                .where(projects_exists)
                .project(1).exists

        sites_exist = sites_exist.not unless exists

        # include reference audio_events when query is for audio_events or audio_event_comments
        model_name = query.model.model_name.name
        check_reference_audio_events = model_name == 'AudioEvent' || model_name == 'AudioEventComment'

        if check_reference_audio_events
          ae_refs = Arel::Table.new(:audio_events)
          ae_refs.table_alias = 'ae_ref'

          ae = AudioEvent.arel_table

          # exists query for audio_events needs to aliased to not get in the way of the main query
          reference_audio_events =
              ae_refs
                  .where(ae_refs[:deleted_at].eq(nil))
                  .where(ae_refs[:is_reference].eq(true))
                  .where(ae_refs[:id].eq(ae[:id]))
                  .project(1).exists

          reference_audio_events = reference_audio_events.not unless exists

          if exists
            query.where(sites_exist.or(reference_audio_events))
          else
            query.where(sites_exist.and(reference_audio_events))
          end
        else
          query.where(sites_exist)
        end
      end

      # Restrict access based on projects.
      # Only used by project queries.
      # Access is allowed if *any* match.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @param [ActiveRecord::Relation] query
      # @return [ActiveRecord::Relation]
      def project_restrictions(user, levels, query)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        pt = Project.arel_table
        pm = Permission.arel_table
        user_id = user.id
        exists, levels = Access::Apply.permission_levels(levels)

=begin
SELECT *
FROM projects
WHERE
    "projects"."deleted_at" IS NULL
    AND ("projects"."creator_id" = 7
    OR
    EXISTS
        (SELECT 1
        FROM "permissions"
        WHERE
            "permissions"."user_id" = 7
            AND "permissions"."level" IN ('reader', 'writer', 'owner')
            AND "projects"."id" = "permissions"."project_id"
        )
    )
=end

        # the 'deleted_at IS NULL' check is added by the ActiveRecord query

        if exists
          project_creator = pt[:creator_id].eq(user_id)
        else
          project_creator = pt[:creator_id].not_eq(user_id)
        end

        project_permissions =
            pm
                .where(pm[:user_id].eq(user_id))
                .where(pm[:level].in(levels))
                .where(pt[:id].eq(pm[:project_id]))
                .project(1)
                .exists

        project_permissions = project_permissions.not unless exists

        if exists
          project_condition = project_creator.or(project_permissions)
        else
          project_condition = project_creator.and(project_permissions)
        end

        query.where(project_condition)
      end

      # Restrict access using project site table
      # @param [Project] project
      # @param [ActiveRecord::Relation] query
      # @return [ActiveRecord::Relation]
      def project_site_restrictions(project, query)
        project = Access::Core.validate_project(project)

        ps = Arel::Table.new(:projects_sites)
        si = Site.arel_table
        project_id = project.id

=begin
SELECT *
FROM sites
WHERE
    EXISTS
        (SELECT 1
        FROM projects_sites
        WHERE
            "sites"."id" = "projects_sites"."site_id"
            AND "projects_sites"."project_id" = 10
        )
=end
        project_condition =
            ps
                .where(si[:id].eq(ps[:site_id]))
                .where(ps[:project_id].eq(project_id))
                .project(1)
                .exists

        query.where(project_condition)
      end

      def saved_search_restrictions(user, levels, query)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        pt = Project.arel_table
        pm = Permission.arel_table
        ps = Arel::Table.new(:projects_saved_searches)
        ss = SavedSearch.arel_table
        user_id = user.id
        exists, levels = Access::Apply.permission_levels(levels)

=begin
SELECT *
FROM saved_searches
WHERE
    EXISTS
        (SELECT 1
        FROM projects_saved_searches
        WHERE
            "saved_searches"."id" = "projects_saved_searches"."saved_search_id"
            AND EXISTS (
                (SELECT 1
                FROM "projects"
                WHERE
                    "projects"."deleted_at" IS NULL
                    AND "projects"."creator_id" = 7
                    AND "projects_saved_searches"."project_id" = "projects"."id"
                )
                UNION ALL
                (SELECT 1
                FROM "permissions"
                WHERE
                    "permissions"."user_id" = 7
                    AND "permissions"."level" IN ('reader', 'writer', 'owner')
                    AND "projects_saved_searches"."project_id" = "permissions"."project_id"
                )
            )
        )

=end
        # user must have at least read access to all projects
        # need to add the 'deleted_at IS NULL' check by hand

        project_creator =
            pt
                .where(pt[:deleted_at].eq(nil))
                .where(pt[:creator_id].eq(user_id))
                .where(ps[:project_id].eq(pt[:id]))
                .project(1)

        project_permissions =
            pm
                .where(pm[:user_id].eq(user_id))
                .where(pm[:level].in(levels))
                .where(ps[:project_id].eq(pm[:project_id]))
                .project(1)

        union_all_projects =
            project_creator
                .union(:all, project_permissions)

        projects_exists = Arel::Nodes::Exists.new(union_all_projects)

        saved_search_exist =
            ps
                .where(ss[:id].eq(ps[:saved_search_id]))
                .where(projects_exists)
                .project(1).exists

        saved_search_exist = saved_search_exist.not unless exists

        query.where(saved_search_exist)
      end

      def audio_event_restriction(user, levels, query)

      end

      # Is exists negated? and which levels should be used to search.
      # @param [Array<Symbol>] levels
      # @return [Boolean, Array<Symbol>] exists, levels
      def permission_levels(levels)
        levels = Access::Core.validate_levels(levels)

        # is_exists = Access::Core.levels_allow.include?(levels)
        # is_not_exists = Access::Core.levels_deny == levels

        # check if any of the deny levels is in levels

        intersection = Access::Core.levels_deny & levels
        # if intersection contains one or more items, then exists must be false
        # or, exists will be true if none of the deny levels are in levels
        exists = intersection.empty?

        # if exists is true, then use the levels that were provided
        # if exists is false, then use all allow levels (as NOT EXISTS will negate it)
        normalised_levels = exists ? levels : Access::Core.levels_allow

        [exists, normalised_levels]
      end

      def restrictions_none(user, query)
        user = Access::Core.validate_user(user)

        unknown = '(unknown)'
        # non-standard users (harvester, guest) have no access
        user_type = unknown
        user_type = 'guest' if Access::Check.is_guest?(user)
        user_type = 'harvester' if Access::Check.is_harvester?(user)

        user_name = user.blank? ? unknown : user.user_name
        user_id = user.blank? ? unknown : user.id
        user_roles = user.blank? ? unknown : user.role_symbols.join(', ')

        msg = "User '#{user_name}', id #{user_id}, type #{user_type}, roles '#{user_roles}' denied access in Access::Query.restrictions."
        Rails.logger.warn msg

        # using .none to be chain-able
        query.none
      end

    end
  end
end

