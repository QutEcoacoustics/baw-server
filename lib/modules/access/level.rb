module Access
  class Level
    class << self

      # Get access level for this user for this project.
      # @param [User] user
      # @param [Project] project
      # @return [Array<Symbol>] level
      def project(user, project)
        projects(user, [project])
      end

      # Get access levels for this user for these projects.
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Array<Symbol>] levels
      def projects(user, projects)
        projects = Access::Core.validate_projects(projects)
        user = Access::Core.validate_user(user)

        # check based on role
        if Access::Check.is_admin?(user)
          :owner
        elsif Access::Check.is_standard_user?(user)
          permission_user_lvl = permissions_user(user, projects)
          permission_logged_in_lvl = permissions_logged_in(projects)

          levels = [permission_user_lvl, permission_logged_in_lvl].flatten.reject { |i| i.blank? }

          levels.blank? ? nil : levels
        elsif Access::Check.is_guest?(user)
          permission_anon_lvl = permissions_anon(projects)
          levels = [permission_anon_lvl].flatten.reject { |i| i.blank? }
          levels.blank? ? nil : levels
        else
          # harvester or invalid role
          nil
        end
      end

      # Get access levels for this user for this project.
      # @param [User] user
      # @param [Project] project
      # @return [Symbol, nil] level
      def permission_user(user, project)
        permissions_user(user, [project])
      end

      # Get access levels for this user for these projects.
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Symbol, nil] level
      def permissions_user(user, projects)
        user = Access::Core.validate_user(user)
        permission_result(projects, user, false, false)
      end

      # Get access levels for anonymous users for this project.
      # @param [Project] project
      # @return [Symbol, nil] level
      def permission_anon(project)
        permissions_anon([project])
      end

      # Get access levels for anonymous users for these projects.
      # @param [Array<Project>] projects
      # @return [Symbol, nil] level
      def permissions_anon(projects)
        permission_result(projects, nil, false, true)
      end

      # Get access levels for logged in users for this project.
      # @param [Project] project
      # @return [Symbol, nil] level
      def permission_logged_in(project)
        permissions_logged_in([project])
      end

      def permissions_logged_in(projects)
        permission_result(projects, nil, true, false)
      end

      private

      def permission_result(projects, user = nil, allow_logged_in = false, allow_anonymous = false)
        projects = Access::Core.validate_projects(projects)
        levels = Permission
                     .where(project: projects, user: user)
                     .where(allow_logged_in: allow_logged_in, allow_anonymous: allow_anonymous)
                     .pluck(:level)
        validated_levels = Access::Core.validate_levels(levels)
        is_none = Access::Core.is_no_level?(validated_levels)
        is_none ? nil : validated_levels
      end

    end
  end
end

