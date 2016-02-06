module Access
  class Level
    class << self
      # Get access level for this user for this project (checks Permission and Project creator).
      # @param [User] user
      # @param [Project] project
      # @return [Symbol] level
      def project(user, project)
        projects(user, [project])
      end

      def projects(user, projects)
        projects = Access::Core.validate_projects(projects)
        user = Access::Core.validate_user(user)

        # check based on role
        if Access::Check.is_admin?(user)
          :owner
        elsif Access::Check.is_standard_user?(user)
          creator_lvl = project_creators(user, projects)
          permission_user_lvl = permissions_user(user, projects)
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
      def permission_user(user, project)
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
          levels.first.to_sym
        end
      end

      # Get access level for this user for these projects (only checks Permission).
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Symbol, nil] level
      def permissions_user(user, projects)
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

      def permission_anon(project)
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

      def permissions_anon(projects)
        projects = Access::Core.validate_projects(projects)

        levels = Permission
                     .where(project: projects, user: nil, logged_in: false, anonymous: true)
                     .pluck(:level).map{ |l| l.to_sym }

        if levels.size < 1
          nil
        else
          Access::Core.highest(levels)
        end
      end

      def permission_logged_in(project)
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

      def permissions_logged_in(projects)
        projects = Access::Core.validate_projects(projects)

        levels = Permission
                     .where(project: projects, user: nil, logged_in: true, anonymous: false)
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
      def project_creator(user, project)
        project_creators(user, [project])
      end

      # Get access level for this user for these project (only checks Project creator).
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Symbol, nil] level
      def project_creators(user, projects)
        projects = Access::Core.validate_projects(projects)
        user = Access::Core.validate_user(user)

        is_creator = projects.any? { |p| p.creator == user }
        is_creator ? :owner : nil
      end
    end
  end
end

