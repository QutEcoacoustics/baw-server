module Access
  class Query
    class << self

      # Get access level for this user for this project (checks Permission and Project creator).
      # @param [User] user
      # @param [Project] project
      # @return [Symbol] level
      def level_project(user, project)
        level_projects(user, [project])
      end

      def level_projects(user, projects)
        projects = Access::Core.validate_projects(projects)
        user = Access::Core.validate_user(user)

        # check based on role
        if Access::Check.is_admin?(user)
          :owner
        elsif Access::Check.is_standard_user?(user)
          creator_lvl = level_project_creators(user, projects)
          permission_user_lvl = level_permissions_user(user, projects)
          #permission_logged_in_lvl = level_permissions_logged_in(projects)

          #levels = [permission_user_lvl, permission_logged_in_lvl].flatten.compact
          levels = [permission_user_lvl, creator_lvl].flatten.compact

          levels.blank? ? :none : Access::Core.highest(levels)
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
      # @param [Project] project
      # @return [Symbol, nil] level
      def level_permission_user(user, project)
        project = Access::Core.validate_project(project)
        user = Access::Core.validate_user(user)

        #.where(project: project, user: user, logged_in: false, anonymous: false)
        levels = Permission
                     .where(project: project, user: user)
                     .pluck(:level)

        if levels.size > 1
          fail ActiveRecord::RecordNotUnique, "Found more than one permission matching project id #{project.id}, user id #{user.id}."
        elsif levels.size < 1
          nil
        else
          levels[0].to_sym
        end
      end

      # Get access level for this user for these projects (only checks Permission).
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Symbol, nil] level
      def level_permissions_user(user, projects)
        projects = Access::Core.validate_projects(projects)
        user = Access::Core.validate_user(user)

        # .where(project: projects, user: user, logged_in: false, anonymous: false)
        levels = Permission
                     .where(project: projects, user: user)
                     .pluck(:level).map{ |l| l.to_sym }

        if levels.size < 1
          nil
        else
          Access::Core.highest(levels)
        end
      end

      def level_permission_anon(project)
        project = Access::Core.validate_project(project)

        levels = Permission
                     .where(project: project, user: nil, logged_in: false, anonymous: true)
                     .pluck(:level)

        if levels.size > 1
          fail ActiveRecord::RecordNotUnique, "Found more than one permission matching anonymous permission for project id #{project.id}."
        elsif levels.size < 1
          nil
        else
          levels[0].to_sym
        end
      end

      def level_permissions_anon(projects)
        projects = Access::Core.validate_projects(projects)

        levels = Permission
                     .where(project: project, user: nil, logged_in: false, anonymous: true)
                     .pluck(:level).map{ |l| l.to_sym }

        if levels.size < 1
          nil
        else
          Access::Core.highest(levels)
        end
      end

      def level_permission_logged_in(project)
        project = Access::Core.validate_project(project)

        levels = Permission
                     .where(project: project, user: nil, logged_in: true, anonymous: false)
                     .pluck(:level)

        if levels.size > 1
          fail ActiveRecord::RecordNotUnique, "Found more than one permission matching logged in permission for project id #{project.id}."
        elsif levels.size < 1
          nil
        else
          levels[0].to_sym
        end
      end

      def level_permissions_logged_in(projects)
        projects = Access::Core.validate_projects(projects)

        levels = Permission
                     .where(project: project, user: nil, logged_in: true, anonymous: false)
                     .pluck(:level).map{ |l| l.to_sym }

        if levels.size < 1
          nil
        else
          Access::Core.highest(levels)
        end
      end

      # Get access level for this user for this project (only checks Project creator).
      # @param [User] user
      # @param [Project] project
      # @return [Symbol, nil] level
      def level_project_creator(user, project)
        level_project_creators(user, [project])
      end

      # Get access level for this user for these project (only checks Project creator).
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Symbol, nil] level
      def level_project_creators(user, projects)
        projects = Access::Core.validate_projects(projects)
        user = Access::Core.validate_user(user)

        is_creator = projects.any? { |p| p.creator == user }
        is_creator ? :owner : nil
      end

      # Get all projects for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] projects
      def projects(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        # .includes eager loads tables using left outer join
        # .references ensures the join is added to the sql when using sql string fragments
        # .joins uses inner join
        # need to use left outer join for permissions, as there might not be a permission, but the project
        # should be included because the user created it
        query = Project.all

        Access::Core.query_project_access(user, levels, query)
      end

      def projects_accessible(user)
        projects(user, Access::Core.levels_allow)
      end

      def projects_inaccessible(user)
        projects(user, Access::Core.levels_deny)
      end

      # Get all sites for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] sites
      def sites(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = Site.joins(:projects)

        Access::Core.query_project_access(user, levels, query)
      end

      # Get all audio recordings for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio recordings
      def audio_recordings(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = AudioRecording.joins(site: :projects)

        Access::Core.query_project_access(user, levels, query)
      end

      # Get all audio events for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio events
      def audio_events(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        # eager load tags and projects
        # @see http://stackoverflow.com/questions/24397640/rails-nested-includes-on-active-records
        # Note that includes works with association names while references needs the actual table name.
        # @see http://api.rubyonrails.org/classes/ActiveRecord/QueryMethods.html#method-i-includes
        query = AudioEvent.joins(audio_recording: [site: [:projects]])

        Access::Core.query_project_access(user, levels, query)
      end

      # Get all audio event comments for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] audio event comments
      def audio_event_comments(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = AudioEventComment.joins(audio_event: [audio_recording: [site: [:projects]]])

        Access::Core.query_project_access(user, levels, query)
      end

      # Get all analysis jobs for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] analysis jobs
      def analysis_jobs(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = AudioEventComment.joins(saved_searches: [projects_saved_searches: [:projects]])

        Access::Core.query_project_access(user, levels, query)
      end

      # Get all saved searches for which this user has this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] saved searches
      def saved_searches(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        query = AudioEventComment.joins(projects_saved_searches: [:projects])

        Access::Core.query_project_access(user, levels, query)
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