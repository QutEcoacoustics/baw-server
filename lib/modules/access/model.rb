module Access
  # Queries to get models by user access level.
  class Model

    # Notes:
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
    class << self

      # Get projects for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] projects
      def projects(user, levels = Access::Core.levels_allow)
        query = Project.order('projects.name ASC')
        is_admin, query = permission_admin(user, levels, query)

        if is_admin
          query
        else
          permissions = permission_projects(user, levels)
          query.where(permissions)
        end

      end

      # Get permissions for this project.
      # @param [Project] project
      # @return [ActiveRecord::Relation] permissions
      def permissions(project)
        project = Access::Core.validate_project(project)
        Permission
            .where(project_id: project.id)
            .order(updated_at: :desc)
      end

      # Get all sites for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @param [Project] project
      # @return [ActiveRecord::Relation] sites
      def sites(user, levels = Access::Core.levels_allow, project = nil)
        # project can be nil
        query = Site.order('lower(sites.name) ASC')
        permission_sites(user, levels, query, project)
      end

      # Get all audio recordings for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio recordings
      def audio_recordings(user, levels = Access::Core.levels_allow)
        query = AudioRecording
                    .joins(:site)
                    .order(recorded_date: :desc)

        permission_sites(user, levels, query)
      end

      # Get all audio events for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @param [AudioRecording] audio_recording
      # @return [ActiveRecord::Relation] audio events
      def audio_events(user, levels = Access::Core.levels_allow, audio_recording = nil)
        # audio_recording can be nil
        query = AudioEvent
                    .joins(audio_recording: [:site])
                    .order(id: :desc)

        if audio_recording
          query = query.where(audio_recording_id: audio_recording.id)
        end

        permission_sites(user, levels, query)
      end

      # Get all audio events tags for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @param [AudioEvent] audio_event
      # @return [ActiveRecord::Relation] audio event tags
      def audio_events_tags(user, levels = Access::Core.levels_allow, audio_event = nil)
        # audio event can be nil
        query = Tagging
                    .joins(audio_event: [audio_recording: [:site]])
                    .order(updated_at: :desc)

        if audio_event
          query = query.where(audio_event_id: audio_event.id)
        end

        permission_sites(user, levels, query)
      end

      # Get all audio events comments for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @param [AudioEvent] audio_event
      # @return [ActiveRecord::Relation] audio event comments
      def audio_event_comments(user, levels = Access::Core.levels_allow, audio_event = nil)
        # audio_event can be nil
        query = AudioEventComment
                    .joins(audio_event: [audio_recording: [:site]])
                    .order(updated_at: :desc)

        if audio_event
          query = query.where(audio_event_id: audio_event.id)
        end

        permission_sites(user, levels, query)
      end

      # Get all saved searches for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] saved searches
      def saved_searches(user, levels = Access::Core.levels_allow)
        query = SavedSearch.order(updated_at: :desc)
        permission_saved_searches(user, levels, query)
      end

      # Get all analysis jobs for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] analysis jobs
      def analysis_jobs(user, levels = Access::Core.levels_allow)
        query = AnalysisJob
                    .joins(:saved_search)
                    .order(updated_at: :desc)
        permission_saved_searches(user, levels, query)
      end

      private

      def permission_admin(user, levels, query)
        # since admin can access everything, any deny level returns nothing
        # admin users have owner access to everything

        is_admin = Access::Check.is_admin?(user)
        if is_admin
          [
              is_admin,
              Access::Core.is_no_level?(levels) ? query.none : query
          ]
        else
          [
              is_admin,
              query
          ]
        end
      end


      def permission_projects(user, levels)
        user = Access::Core.validate_user(user)

=begin
  [NOT] EXISTS
    (SELECT 1
    FROM "permissions"
    WHERE
      "permissions"."level" IN ('reader', 'writer', 'owner')
      AND "projects"."id" = "permissions"."project_id"
      AND "projects"."deleted_at" IS NULL
      AND ("permissions"."user_id" = :user_id
          OR "permissions"."allow_anonymous" = TRUE
          OR "permissions"."allow_logged_in" = TRUE
          )
    )
=end

        pt = Project.arel_table
        pm = Permission.arel_table
        levels, exists = calculate_levels(levels)

        project_permissions =
            pm
                .where(pm[:level].in(levels))
                .where(pt[:id].eq(pm[:project_id]))
                .where(pt[:deleted_at].eq(nil))

        if user.blank?
          # only anon permissions allow to guest user
          project_permissions =
              project_permissions
                  .where(pm[:allow_anonymous].eq(true))
        else
          # a logged in user can use
          # - individual permissions
          # - logged in permissions
          # - anon permissions
          project_permissions =
              project_permissions
                  .where(pm[:user_id].eq(user.id).or(
                             pm[:allow_logged_in].eq(true).or(
                                 pm[:allow_anonymous].eq(true))))
        end

        project_permissions = project_permissions.project(1).exists

        exists ? project_permissions : project_permissions.not
      end

      # many to many join projects and sites
      def permission_sites(user, levels, query, project = nil)

        is_admin, query = permission_admin(user, levels, query)
        return query if is_admin

=begin
  EXISTS
      (SELECT 1
      FROM projects_sites
      INNER JOIN projects ON projects.is = projects_site.project_id
      WHERE
          "sites"."id" = "projects_sites"."site_id"
          AND <permission_projects>
      )
=end
        pt = Project.arel_table
        ps = Arel::Table.new(:projects_sites)
        st = Site.arel_table
        levels, exists = calculate_levels(levels)

        # project permission will never be nil, which is the way it should work
        # when being used as a part of a subquery rather than the whole subquery
        permissions = permission_projects(user, levels)

        permissions_by_site =
            ps
                .join(pt).on(ps[:project_id].eq(pt[:id]))
                .where(ps[:site_id].eq(st[:id]))

        # filter by project if it is specified
        if project
          permissions_by_site =
              permissions_by_site
                  .where(pt[:id].eq(project.id))
        end

        permissions_by_site =
            permissions_by_site
                .where(permissions)
                .project(1)
                .exists

        permissions_by_site = exists ? permissions_by_site : permissions_by_site.not
=begin
  EXISTS
    (SELECT 1
    FROM "audio_events" ae_ref
    WHERE
        ae_ref."deleted_at" IS NULL
        AND ae_ref."is_reference" = TRUE
        AND "audio_events"."id" = ae_ref.id
    )
=end
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

          reference_audio_events = exists ? reference_audio_events : reference_audio_events.not

          if exists
            query.where(permissions_by_site.or(reference_audio_events))
          else
            query.where(permissions_by_site.and(reference_audio_events))
          end
        else
          query.where(permissions_by_site)
        end

      end

      def permission_saved_searches(user, levels, query)
        is_admin, query = permission_admin(user, levels, query)
        return query if is_admin

=begin
  EXISTS
      (SELECT 1
      FROM projects_saved_searches
      INNER JOIN projects ON projects.id = projects_saved_searches.project_id
      WHERE
          "saved_searches"."id" = "projects_saved_searches"."saved_search_id"
          AND <permission_projects>
      )
=end
        pt = Project.arel_table
        ps = Arel::Table.new(:projects_saved_searches)
        ss = SavedSearch.arel_table
        levels, exists = calculate_levels(levels)

        permissions = permission_projects(user, levels)

        permissions_by_saved_search =
            ps
                .join(pt).on(ps[:project_id].eq(pt[:id]))
                .where(ps[:saved_search_id].eq(ss[:id]))
                .where(permissions)
                .project(1)
                .exists

        exists ? permissions_by_saved_search : permissions_by_saved_search.not
      end

      def calculate_levels(levels)
        # levels can be nil to indicate get projects user has no access
        levels = Access::Core.validate_levels(levels)

        # exists is false when no levels are specified
        exists = !Access::Core.is_no_level?(levels)

        # if exists is true, then use the levels that were provided
        # if exists is false, then use all allow levels (as NOT EXISTS will negate it)
        levels = exists ? levels : Access::Core.levels_allow

        [levels, exists]
      end

    end
  end
end