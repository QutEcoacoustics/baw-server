module Access
  class Query
    class << self

      # Get all users that have levels access or higher to project.
      # @param [Project, Array<Project>] projects
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] users
      def users(projects, levels = Access::Core.levels_allow)
        projects = Access::Core.validate_projects(projects)
        levels = Access::Core.validate_levels(levels)
        is_none = Access::Core.is_no_level?(levels)

        if is_none
          # get all users who have no access to the project
          # will never include any admins
          # if project has anon access, will always return empty
          # if project has logged in access, will return only 'guest'
          # SQL query for users where not exists permission entries for this project and equal or greater levels
          # SQL query should check user type, as admins will always have access

        else
          # get all users who have at least the lowest level access to the project
          # will always include all admins
          # needs to account for anon and logged in access settings
          # SQL query for users where exists permission entries for this project and equal or greater levels
          # SQL query should check user type, as admins will always have access
          lowest_level = Access::Core.lowest(levels)
          equal_or_greater_levels = Access::Core.equal_or_greater(lowest_level)
        end

        fail NotImplementedError
      end

      # Get projects for which this user has these levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] projects
      def projects(user, levels)
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
        projects(user, nil)
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
                    .order(id: :desc)
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

      def audio_events_tags_modified(user)
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