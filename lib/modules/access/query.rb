module Access
  class Query
    class << self

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



    end
  end
end