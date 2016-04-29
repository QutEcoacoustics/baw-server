module Access
  class Query
    class << self

      # Get all users that have levels access or higher to project.
      # @param [Project] project
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] users
      def users(project, levels = Access::Core.levels_allow)
        fail NotImplementedError

        levels = Access::Core.validate_levels(levels)
        project = Access::Core.validate_project(project)

        if levels == [:none]
          # get all users who have no access to the project
          # will never include any admins
          # if project has anon access, will always return empty
          # if project has logged in access, will return only 'guest'
          # SQL query for users where not exists permission entries for this project and equal or greater levels
          # SQL query should check user type, as admins will always have access
        else
          # get all users who have at least the lowest of levels access to the project
          # will always include all admins
          # needs to account for anon and logged in access settings
          # SQL query for users where exists permission entries for this project and equal or greater levels
          # SQL query should check user type, as admins will always have access
          lowest_level = Access::Core.lowest(levels)
          equal_or_greater_levels = Access::Core.equal_or_greater(lowest_level)
        end
      end

      # Get lowest access level for this user for these projects (checks Permission and Project creator).
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Symbol] level
      def level_projects_lowest(user, projects)
        projects = Access::Core.validate_projects(projects)
        user = Access::Core.validate_user(user)

        # check based on role
        if Access::Check.is_admin?(user)
          :owner
        elsif Access::Check.is_standard_user?(user)
          creator_lvl = Access::Level.project_creators(user, projects)
          permission_user_lvl = Access::Level.permissions_user(user, projects)
          #permission_logged_in_lvl = level_permissions_logged_in(projects)

          #levels = [permission_user_lvl, permission_logged_in_lvl].flatten.compact
          levels = [permission_user_lvl, creator_lvl].flatten.compact

          levels.blank? ? :none : Access::Core.lowest(levels)
        elsif Access::Check.is_guest?(user)
          #permission_anon_lvl = level_permissions_anon(projects)
          #permission_anon_lvl.blank? ? :none : Access::Core.highest([permission_anon_lvl].flatten)
          # remove :none once additional permissions are added
          :none
        else
          # guest, harvester, or invalid role
          :none
        end
      end

      # Get access level for this user for this project (only checks Permission).
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] projects
      def projects(user, levels = Access::Core.levels_allow)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = Project.order('lower(projects.name) ASC')
        Access::Apply.restrictions(user, levels, query)
      end

      # Get all projects this user can access.
      # @param [User] user
      # @return [ActiveRecord::Relation] projects
      def projects_accessible(user)
        projects(user, Access::Core.levels_allow)
      end

      # Get all projects this user can not access.
      # @param [User] user
      # @return [ActiveRecord::Relation] projects
      def projects_inaccessible(user)
        projects(user, Access::Core.levels_deny)
      end

      # Get all permissions.
      # @return [ActiveRecord::Relation] permissions
      def permissions
        Permission.order(updated_at: :desc)
      end

      # Get all permissions for this project.
      # @param [Project] project
      # @return [ActiveRecord::Relation] permissions
      def project_permissions(project)
        project = Access::Core.validate_project(project)
        Access::Query.permissions.where(project_id: project.id)
      end

      # Get all sites for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] sites
      def sites(user, levels = Access::Core.levels_allow)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = Site.order('lower(sites.name) ASC')
        Access::Apply.restrictions(user, levels, query)
      end

      # Get all sites in project for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] sites
      def project_sites(project, user, levels = Access::Core.levels_allow)
        project = Access::Core.validate_project(project)

        query = Access::Query.sites(user, levels)
        Access::Apply.project_site_restrictions(project, query)
      end

      # Get all audio recordings for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio recordings
      def audio_recordings(user, levels = Access::Core.levels_allow)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = AudioRecording
                    .joins(:site)
                    .order(recorded_date: :desc)
        Access::Apply.restrictions(user, levels, query)
      end

      # Get all audio events for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio events
      def audio_events(user, levels = Access::Core.levels_allow)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = AudioEvent
                    .joins(audio_recording: [:site])
        Access::Apply.restrictions(user, levels, query)
      end

      # Get all audio events attached to an audio recording
      # for which this user has this user has these access levels.
      # @param [AudioRecording] audio_recording
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio events
      def audio_recording_audio_events(audio_recording, user, levels = Access::Core.levels_allow)
        audio_recording = Access::Core.validate_audio_recording(audio_recording)

        query = Access::Query.audio_events(user, levels)
        query.where(audio_recording_id: audio_recording.id)
      end

      # Get all audio event comments for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio event comments
      def comments(user, levels = Access::Core.levels_allow)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = AudioEventComment
                    .joins(audio_event: [audio_recording: [:site]])
                    .order(updated_at: :desc)
        Access::Apply.restrictions(user, levels, query)
      end

      # Get all audio event comments attached to an audio event
      # for which this user has this user has these access levels.
      # @param [AudioEvent] audio_event
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio event comments
      def audio_event_comments(audio_event, user, levels = Access::Core.levels_allow)
        audio_event = Access::Core.validate_audio_event(audio_event)

        query = Access::Query.comments(user, levels)
        query.where(audio_event_id: audio_event.id)
      end

      # Get all taggings for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] taggings
      def taggings(user, levels = Access::Core.levels_allow)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = Tagging
                    .joins(audio_event: [audio_recording: [:site]])
                    .order(updated_at: :desc)
        Access::Apply.restrictions(user, levels, query)
      end

      # Get all taggings of an audio event
      # for which this user has this user has these access levels.
      # @param [AudioEvent] audio_event
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] taggings
      def audio_event_taggings(audio_event, user, levels = Access::Core.levels_allow)
        audio_event = Access::Core.validate_audio_event(audio_event)

        query = Access::Query.taggings(user, levels)
        query.where(audio_event_id: audio_event.id)
      end

      # Get all analysis jobs for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] analysis jobs
      def analysis_jobs(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = AnalysisJob.joins(:saved_search).order(updated_at: :desc)
        Access::Apply.restrictions(user, levels, query)
      end

      # Get all analysis jobs items for which this user has this user has these access levels.
      # @param [AnalysisJob] analysis_job
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] analysis jobs items
      def analysis_jobs_items(analysis_job, user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        # The original results endpoint does permissions through audio_recordings so we're emulating that here. It
        # ***should*** be functionally equivalent to checking permissions through the
        # AnalysisJob.SavedSearch.Projects relationship.

        query = AnalysisJobsItem
                    .joins(:audio_recording)
                    .order(created_at: :desc)
                    .joins(:analysis_job)
                    .where(analysis_job: {id: analysis_job.id})

            Access::Apply.restrictions(user, levels, query)
      end


      # Get all saved searches for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] saved searches
      def saved_searches(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = SavedSearch.order(created_at: :desc)

        Access::Apply.restrictions(user, levels, query)
      end

      def taggings_modified(user)
        user = Access::Core.validate_user(user)
        Tagging.where('(audio_events_tags.creator_id = ? OR audio_events_tags.updater_id = ?)', user.id, user.id)
      end

      def audio_events_modified(user)
        user = Access::Core.validate_user(user)
        AudioEvent.where('(audio_events.creator_id = ? OR audio_events.updater_id = ?)', user.id, user.id)
      end

      def bookmarks_modified(user)
        user = Access::Core.validate_user(user)
        Bookmark.where('(bookmarks.creator_id = ? OR bookmarks.updater_id = ?)', user.id, user.id)
      end

      def audio_event_comments_modified(user)
        user = Access::Core.validate_user(user)
        AudioEventComment.where('(audio_event_comments.creator_id = ? OR audio_event_comments.updater_id = ?)', user.id, user.id)
      end

      def saved_searches_modified(user)
        user = Access::Core.validate_user(user)
        SavedSearch.where('(saved_searches.creator_id = ?)', user.id)
      end

      def analysis_jobs_modified(user)
        user = Access::Core.validate_user(user)
        AnalysisJob.where('(analysis_jobs.creator_id = ? OR analysis_jobs.updater_id = ?)', user.id, user.id)
      end

    end
  end
end