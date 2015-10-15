module Access
  # Query by user and project to get levels.
  class Level
    class << self

      # Get access levels for this user for these projects.
      # @param [User] user
      # @param [Project, Array<Project>] projects
      # @return [Array<Symbol>] levels
      def all(user, projects)
        projects = Access::Core.validate_projects([projects])
        user = Access::Core.validate_user(user)

        # check based on role
        if Access::Check.is_admin?(user)
          :owner
        elsif Access::Check.is_standard_user?(user)
          permission_user_lvl = user(user, projects)
          permission_logged_in_lvl = logged_in(projects)
          permission_anon_lvl = anonymous(projects)

          levels = [permission_user_lvl, permission_logged_in_lvl, permission_anon_lvl].flatten.reject { |i| i.blank? }.uniq

          levels.blank? ? nil : levels
        elsif Access::Check.is_guest?(user)
          permission_anon_lvl = anonymous(projects)
          levels = [permission_anon_lvl].flatten.reject { |i| i.blank? }.uniq
          levels.blank? ? nil : levels
        else
          # harvester or invalid role
          nil
        end
      end

      # Get access levels for this user for this project.
      # @param [User] user
      # @param [Project, Array<Project>] projects
      # @return [Symbol, nil] level
      def user(user, projects)
        user = Access::Core.validate_user(user)
        levels = permission([projects], user, false, false)
        if !levels.blank? && levels.size != 1
          fail ArgumentError, "Expected zero or one permissions for #{user.user_name} for #{project.name}, got #{levels.size}"
        end
        levels.blank? ? nil : levels.first
      end

      # Get access levels for anonymous users for this project.
      # @param [Project, Array<Project>] projects
      # @return [Symbol, nil] level
      def anonymous(projects)
        levels = permission([projects], nil, false, true)
        if !levels.blank? && levels.size != 1
          fail ArgumentError, "Expected zero or one anonymous permissions for #{project.name}, got #{levels.size}"
        end
        levels.blank? ? nil : levels.first
      end

      # Get access levels for logged in users for this project.
      # @param [Project, Array<Project>] projects
      # @return [Symbol, nil] level
      def logged_in(projects)
        levels =  permission([projects], nil, true, false)
        if !levels.blank? && levels.size != 1
          fail ArgumentError, "Expected zero or one logged in permissions for #{project.name}, got #{levels.size}"
        end
        levels.blank? ? nil : levels.first
      end

      private

      def permission(projects, user = nil, allow_logged_in = false, allow_anonymous = false)
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

